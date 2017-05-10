require 'spec_helper'

describe Wesm do
  let(:state_machine) { WesmHelper.class_with_wesm }

  describe 'public methods' do
    describe '.transition' do
      it 'adds instance of Transition class to transitions hash' do
        module Wrapper
          class SomeClass; end
        end

        state_machine.class_eval do
          transition :initial => :approved, performer: Wrapper::SomeClass, actor: :owner,
                                            scope: { type: 'any' }, required: :something
        end

        transitions = state_machine.class_eval { @transitions }

        expect(transitions.keys.first).to eq 'initial'
        expect(transitions['initial'].class).to eq Array

        added_transition = transitions['initial'].first

        expect(added_transition.from_state).to eq 'initial'
        expect(added_transition.to_state).to eq 'approved'
        expect(added_transition.instance_eval { @valid_actors }).to eq [:owner]
        expect(added_transition.instance_eval { @scope }).to eq({ type: 'any' })
        expect(added_transition.required).to eq [:something]
        expect(added_transition.performer).to eq Wrapper::SomeClass
        expect(added_transition.frozen?).to eq true

        Object.send(:remove_const, :Wrapper)
      end
    end

    describe '.successors' do
      it 'returns hash with next possible states based on object\'s current state and constraints' do
        state_machine.instance_eval do
          transition :initial => :shipped, scope: { type: 'first' }
          transition :initial => :paid, scope: { type: 'first' }
          transition :initial => :pending, scope: { type: 'first' }
          transition :initial => :awaits_payment, scope: { type: 'second' }
          transition :awaits_payment => :paid, scope: { type: 'first' }
        end

        object = Object.new
        object.stub(:type) { 'first' }
        object.stub(:state) { 'initial' }

        expect(state_machine.successors(object)).to eq(%w(shipped paid pending))
      end
    end

    describe '.show_transitions' do
      it 'returns available transitions with additional info' do
        state_machine.instance_eval do
          transition :initial => :paid, actor: :consumer, scope: { type: 'first' }, required: :payment
          transition :initial => :approved, actor: :consumer, scope: { type: 'first' }, required: :confirmation
          transition :initial => :awaits_payment, actor: :consumer
          transition :initial => :shipped, actor: :supplier
          transition :paid => :shipped, actor: :consumer
        end

        user = Object.new
        second_user = Object.new
        object = Object.new
        object.stub(:consumer) { user }
        object.stub(:supplier) { second_user }
        object.stub(:type) { 'first' }
        object.stub(:state) { 'initial' }
        object.stub(:payment)
        object.stub(:confirmation) { Object.new }

        expect(state_machine.show_transitions(object, user))
          .to eq([{ to_state: 'paid', is_authorized: true, can_perform: false, required_fields: [:payment] },
                  { to_state: 'approved', is_authorized:true, can_perform: true, required_fields: [] },
                  { to_state: 'awaits_payment', is_authorized: true, can_perform: true, required_fields: [] },
                  { to_state: 'shipped', is_authorized: false, can_perform: false, required_fields: [] }])
      end
    end

    describe '.required_fields' do
      it 'returns required_fields if transition is present, else returns nil' do
        state_machine.transition :initial => :paid, actor: :consumer, required: [:payment, :anything]

        user = Object.new
        object = Object.new
        object.stub(:consumer) { user }
        object.stub(:state) { 'initial' }
        object.stub(:payment)
        object.stub(:anything)

        expect(state_machine.required_fields(object, 'paid'))
          .to eq [:payment, :anything]
        expect(state_machine.required_fields(object, 'not_valid_next_state'))
          .to eq nil

        object.stub(:payment) { Object.new }

        expect(state_machine.required_fields(object, 'paid'))
          .to eq [:anything]
      end
    end

    describe '.perform_transition' do
      let(:object) { WesmHelper.object_with_attrs(:state) }
      let(:first_user) { Object.new }
      let(:second_user) { Object.new }

      before do
        state_machine.transition :initial => :paid, actor: :consumer, required: :payment

        object.stub(:consumer) { first_user }
        object.stub(:supplier) { second_user }
        object.stub(:payment) { Object.new }
        object.state = 'initial'
      end

      context 'when all conditions pass' do
        it 'performs transition' do
          state_machine.perform_transition(object, 'paid', first_user)

          expect(object.state).to eq 'paid'
        end

        it 'calls process_transition method' do
          transition = state_machine.instance_eval { @transitions['initial'].first }

          expect(state_machine).to receive(:process_transition).with(object, transition, first_user)

          state_machine.perform_transition(object, 'paid', first_user)
        end
      end

      context 'when at least one condition do not pass' do
        it 'raises access violation error if actor is invalid' do
          expect { state_machine.perform_transition(object, 'paid', second_user) }
            .to raise_error(Wesm::AccessViolationError)
        end

        it 'raises transition requirement error if object has nil required fields' do
          object.stub(:payment)

          expect { state_machine.perform_transition(object, 'paid', first_user) }
            .to raise_error(Wesm::TransitionRequirementError)
        end

        it 'raises unexpected transition error if transition not found' do
          expect { state_machine.perform_transition(object, 'another_state', first_user) }
            .to raise_error(Wesm::UnexpectedTransitionError)
        end

        it 'raises unexpected transition error if scope excludes object' do
          state_machine.transition :initial => :approved, actor: :consumer, scope: { type: 'specific' }
          object.stub(:type) { 'original' }

          expect { state_machine.perform_transition(object, 'approved', first_user) }
            .to raise_error(Wesm::UnexpectedTransitionError)
        end
      end

      it 'can be used with multiple extra arguments' do
        state_machine.class_eval do
          transition :initial => :paid, actor: :consumer
        end

        transition = state_machine.instance_eval { @transitions['initial'].first }

        object.stub(:consumer) { first_user }
        object.state = 'initial'

        expect(state_machine).to \
          receive(:process_transition).with(object, transition, first_user, 1, 2, 3)

        state_machine.perform_transition(object, 'paid', first_user, 1, 2, 3)
      end
    end
  end

  describe 'private methods' do
    describe '.transitions_for' do
      it 'returns allowed transitions based on object state and constraints' do
        state_machine.instance_eval do
          transition :initial => :shipped, actor: :supplier, scope: { type: 'first' }
          transition :initial => :paid, actor: :consumer, scope: { type: 'first' }
          transition :initial => :pending, actor: :consumer, scope: { type: 'first' }
          transition :initial => :awaits_payment, actor: :consumer, scope: { type: 'second' }
          transition :awaits_payment => :paid, actor: :consumer, scope: { type: 'first' }
        end

        transitions = state_machine.instance_eval do @transitions['initial'] end

        first_user = Object.new
        second_user = Object.new
        object = Object.new
        object.stub(:supplier) { first_user }
        object.stub(:consumer) { second_user }
        object.stub(:type) { 'first' }
        object.stub(:state) { 'initial' }

        expect(state_machine.send(:transitions_for, object))
          .to eq([transitions[0], transitions[1], transitions[2]])
      end
    end

    describe '.get_transition' do
      let(:user) { Object.new }
      let(:object) { Object.new }

      before do
        state_machine.instance_eval do
          transition :initial => :approved, actor: :consumer, scope: { type: 'first' }
          transition :initial => :awaits_payment, actor: :consumer
        end

        object.stub(:consumer) { user }
        object.stub(:type) { 'first' }
        object.stub(:state) { 'initial' }
      end

      context 'when suitable transition exists' do
        it 'returns transition object' do
          transition = state_machine.send(:get_transition, object, 'awaits_payment')
          expected_transition = state_machine.instance_eval { @transitions['initial'][1] }

          expect(transition).to eq expected_transition
        end
      end

      context 'when suitable transition does not exists' do
        it 'returns nil' do
          transition = state_machine.send(:get_transition, object, 'shipped')

          expect(transition).to be_nil
        end
      end
    end

    describe '.get_transition!' do
      let(:user) { Object.new }
      let(:object) { Object.new }

      before do
        state_machine.instance_eval do
          transition :initial => :approved, actor: :consumer, scope: { type: 'first' }
          transition :initial => :awaits_payment, actor: :consumer
        end

        object.stub(:consumer) { user }
        object.stub(:type) { 'first' }
        object.stub(:state) { 'initial' }
      end

      context 'when suitable transition exists' do
        it 'returns transition object' do
          transition = state_machine.send(:get_transition!, object, 'awaits_payment', user)
          expected_transition = state_machine.instance_eval { @transitions['initial'][1] }

          expect(transition).to eq expected_transition
        end
      end

      context 'when suitable transition does not exists' do
        it 'raises exception' do
          invalid_user = Object.new

          expect { state_machine.send(:get_transition!, object, 'awaits_payment', invalid_user) }
            .to raise_error(Wesm::AccessViolationError)
        end
      end
    end
  end

  it 'provides methods to custom module with correct scope' do
    public_methods = %i(transition successors show_transitions required_fields perform_transition)
    private_methods = %i(transitions_for get_transition get_transition! state_field)

    expect(public_methods.all?(&-> (method) { state_machine.methods.include?(method) }))
      .to eq true
    expect(private_methods.all?(&-> (method) { state_machine.private_methods.include?(method) }))
      .to eq true
  end

  it 'has a version number' do
    expect(Wesm::VERSION).not_to be nil
  end
end
