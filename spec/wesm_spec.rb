require 'spec_helper'

describe Wesm do
  let(:custom_module) { WesmHelper.module_with_wesm }

  describe '.transition' do
    it 'adds instance of Transition class to transitions hash' do
      custom_module.instance_eval do
        transition :pending => :approved, performer: :approving, actor: :owner,
                                          where: { type: 'any' }, required: :something
      end

      transitions = custom_module.instance_eval do @transitions end

      expect(transitions.keys.first).to eq 'pending'
      expect(transitions['pending'].class).to eq Array

      added_transition = transitions['pending'].first

      expect(added_transition.from_state).to eq 'pending'
      expect(added_transition.to_state).to eq 'approved'
      expect(added_transition.performer).to eq :approving
      expect(added_transition.instance_eval do @allowed_actors end)
        .to eq :owner
      expect(added_transition.instance_eval do @constraints end)
        .to eq({ type: 'any' })
      expect(added_transition.instance_eval do @required_fields end)
        .to eq [:something]
      expect(added_transition.frozen?).to eq true
    end
  end

  describe '.successors' do
    it 'returns hash with next possible states based on current state, constraints and transition actor' do
      custom_module.instance_eval do
        transition :initial => :shipped, actor: :supplier, where: { type: 'first' }
        transition :initial => :paid, actor: :consumer, where: { type: 'first' }
        transition :initial => :pending, actor: :consumer, where: { type: 'first' }
        transition :initial => :awaits_payment, actor: :consumer, where: { type: 'second' }
        transition :awaits_payment => :paid, actor: :consumer, where: { type: 'first' }
      end

      first_user = Object.new
      second_user = Object.new
      object = Object.new
      object.stub(:supplier) { first_user }
      object.stub(:consumer) { second_user }
      object.stub(:type) { 'first' }
      object.stub(:state) { 'initial' }

      expect(custom_module.successors(object, first_user)).to eq ['shipped']
      expect(custom_module.successors(object, second_user)).to eq ['paid', 'pending']
    end
  end

  describe '.show_transitions' do
    it 'returns available transitions with additional info' do
      custom_module.instance_eval do
        transition :initial => :paid, actor: :consumer, where: { type: 'first' }, required: :payment
        transition :initial => :approved, actor: :consumer, where: { type: 'first' }, required: :confirmation
        transition :initial => :awaits_payment, actor: :consumer
      end

      user = Object.new
      object = Object.new
      object.stub(:consumer) { user }
      object.stub(:type) { 'first' }
      object.stub(:state) { 'initial' }
      object.stub(:payment) { nil }
      object.stub(:confirmation) { Object.new }

      expect(custom_module.show_transitions(object, user))
        .to eq([{ to_state: 'paid', can_perform: false, required_fields: [:payment] },
                { to_state: 'approved', can_perform: true, required_fields: [:confirmation] },
                { to_state: 'awaits_payment', can_perform: true, required_fields: [] }])
    end
  end

  describe '.required_fields' do
    it 'returns required_fields if transition is present, else returns nil' do
      custom_module.transition :initial => :paid, actor: :consumer, required: [:payment, :anything]

      user = Object.new
      object = Object.new
      object.stub(:consumer) { user }
      object.stub(:state) { 'initial' }

      expect(custom_module.required_fields(object, user, 'paid'))
        .to eq [:payment, :anything]
      expect(custom_module.required_fields(object, user, 'not_valid_next_state'))
        .to eq nil
    end
  end

  describe '.perform_transition' do
    let(:object) { MockConstructor.object_with_attr_accessors(:state) }
    let(:first_user) { Object.new }
    let(:second_user) { Object.new }

    before do
      custom_module.transition :initial => :paid, actor: :consumer, required: :payment

      object.stub(:consumer) { first_user }
      object.stub(:supplier) { second_user }
      object.stub(:payment) { Object.new }
      object.state = 'initial'
    end

    context 'when all conditions pass' do
      it 'performs transition' do
        custom_module.perform_transition(object, first_user, 'paid')

        expect(object.state).to eq 'paid'
      end

      it 'calls run_performer_method' do
        transition = custom_module.instance_eval { @transitions['initial'].first }

        expect(custom_module)
          .to receive(:run_performer_method).with(:before_transition, object, transition)
        expect(custom_module)
          .to receive(:run_performer_method).with(:after_transition, object, transition)

        custom_module.perform_transition(object, first_user, 'paid')
      end

      it 'calls persist_object method' do
        transition = custom_module.instance_eval { @transitions['initial'].first }

        expect(custom_module).to receive(:persist_object).with(object, transition)

        custom_module.perform_transition(object, first_user, 'paid')
      end
    end

    context 'when at least one condition do not pass' do
      it 'raises access violation error if actor is invalid' do
        expect { custom_module.perform_transition(object, second_user, 'paid') }
          .to raise_error(Wesm::AccessViolationError)
      end

      it 'raises access violation error if some of required fields are blank' do
        object.stub(:payment) { nil }

        expect { custom_module.perform_transition(object, first_user, 'paid') }
          .to raise_error(Wesm::AccessViolationError)
      end

      it 'raises access violation error if transition not found' do
        expect { custom_module.perform_transition(object, first_user, 'another_state') }
          .to raise_error(Wesm::AccessViolationError)
      end

      it 'raises access violation error if constraints for object do not pass' do
        custom_module.transition :initial => :approved, actor: :consumer, where: { type: 'specific' }
        object.stub(:type) { 'original' }

        expect { custom_module.perform_transition(object, first_user, 'approved') }
          .to raise_error(Wesm::AccessViolationError)
      end
    end
  end

  describe '.run_performer_method' do
    let(:object) { Object.new }

    it 'calls methods from defined in transition performer' do
      module CustomModule
        extend Wesm

        transition :initial => :paid, performer: :paying

        module Paying
          def self.before_transition(object, transition)
          end

          def self.after_transition(object, transition)
          end
        end
      end

      expect(CustomModule::Paying).to receive(:before_transition)
      expect(CustomModule::Paying).to receive(:after_transition)

      transition = CustomModule.instance_eval { @transitions['initial'].first }
      CustomModule.send(:run_performer_method, :before_transition, object, transition)
      CustomModule.send(:run_performer_method, :after_transition, object, transition)

      Object.send(:remove_const, :CustomModule)
    end
  end

  describe '.authorized_transitions' do
    it 'returns allowed transitions based on object state and constraints' do
      custom_module.instance_eval do
        transition :initial => :shipped, actor: :supplier, where: { type: 'first' }
        transition :initial => :paid, actor: :consumer, where: { type: 'first' }
        transition :initial => :pending, actor: :consumer, where: { type: 'first' }
        transition :initial => :awaits_payment, actor: :consumer, where: { type: 'second' }
        transition :awaits_payment => :paid, actor: :consumer, where: { type: 'first' }
      end

      transitions = custom_module.instance_eval do @transitions['initial'] end

      first_user = Object.new
      second_user = Object.new
      object = Object.new
      object.stub(:supplier) { first_user }
      object.stub(:consumer) { second_user }
      object.stub(:type) { 'first' }
      object.stub(:state) { 'initial' }

      expect(custom_module.send(:authorized_transitions, object, second_user))
        .to eq([transitions[1], transitions[2]])
    end
  end

  it 'provides methods to custom module with correct scope' do
    public_methods = %i(transition successors show_transitions required_fields
                        perform_transition)
    private_methods = %i(authorized_transitions get_transition get_transition!
                         get_performer state_field run_performer_method)

    expect(public_methods.all?(&-> (method) { custom_module.methods.include?(method) }))
      .to eq true
    expect(private_methods.all?(&-> (method) { custom_module.private_methods.include?(method) }))
      .to eq true
  end

  it 'has a version number' do
    expect(Wesm::VERSION).not_to be nil
  end
end
