require 'spec_helper'

describe Wesm do
  def undefine_dummy_module
    Object.send(:remove_const, :CustomModule) if Module.const_defined?(:CustomModule)
  end

  before(:each) {  undefine_dummy_module }

  describe '.transition' do
    it 'adds instance of Transition class to transitions hash' do
      module CustomModule
        extend Wesm

        transition :pending => :approved, performer: :approving, actor: :owner, where: { type: 'any' },
                                          required: :something
      end

      transitions = CustomModule.instance_eval do @transitions end

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
      module CustomModule
        extend Wesm

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

      expect(CustomModule.successors(object, first_user)).to eq ['shipped']
      expect(CustomModule.successors(object, second_user)).to eq ['paid', 'pending']
    end
  end

  describe '.show_transitions' do
    it 'returns available transitions with additional info' do
      module CustomModule
        extend Wesm

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

        expect(CustomModule.show_transitions(object, user))
          .to eq([{ to_state: 'paid', can_perform: false, required_fields: [:payment] },
                  { to_state: 'approved', can_perform: true, required_fields: [:confirmation] },
                  { to_state: 'awaits_payment', can_perform: true, required_fields: [] }])
    end
  end

  it 'provides methods to custom module with correct scope' do
    module CustomModule
      extend Wesm
    end

    public_methods = %i(transition successors show_transitions required_fields
                        perform_transition)
    private_methods = %i(authorized_transitions get_transition get_transition!
                         performers_scope get_performer state_field run_performer_method)

    expect(public_methods.all?(&-> (method) { CustomModule.methods.include?(method) }))
      .to eq true
    expect(private_methods.all?(&-> (method) { CustomModule.private_methods.include?(method) }))
      .to eq true
  end

  it 'has a version number' do
    expect(Wesm::VERSION).not_to be nil
  end
end
