require 'spec_helper'

describe Wesm::Transition do
  describe 'public methods' do
    describe '.actor_is_valid?' do
      let(:object) { Object.new }
      let(:user_class) { Class.new(Object) }
      let(:user) { user_class.new }

      before { object.stub(:owner) { user } }

      it 'works with single actor' do
        transition = Wesm::Transition.new(initial: :verified, actor: :owner)
        invalid_user = user_class.new

        expect(transition.actor_is_valid?(object, user)).to eq true
        expect(transition.actor_is_valid?(object, invalid_user)).to eq false
      end

      it 'works with multiple actors' do
        transition = Wesm::Transition.new(initial: :verified, actor: [:owner, :watcher])
        second_user = user_class.new
        invalid_user = user_class.new
        object.stub(:watcher) { second_user }

        expect(transition.actor_is_valid?(object, user)).to eq true
        expect(transition.actor_is_valid?(object, second_user)).to eq true
        expect(transition.actor_is_valid?(object, invalid_user)).to eq false
      end
    end

    describe '.required_fields_present?' do
      let(:object) { Object.new }

      it 'works with single field' do
        transition = Wesm::Transition.new(initial: :verified, required: :info)
        object.stub(:info) { 'something' }

        expect(transition.required_fields_present?(object)).to eq true

        object.stub(:info)

        expect(transition.required_fields_present?(object)).to eq false
      end

      it 'works with multiple fields' do
        transition = Wesm::Transition.new(initial: :verified, required: [:info, :creation_date])
        object.stub(:info) { 'something' }
        object.stub(:creation_date) { Time.now }

        expect(transition.required_fields_present?(object)).to eq true

        object.stub(:info)

        expect(transition.required_fields_present?(object)).to eq false
      end
    end

    describe '.constraints_pass?' do
      let(:object) { Object.new }

      it 'works with single constraint' do
        transition = Wesm::Transition.new(initial: :verified, where: { type: 'first' })
        object.stub(:type) { 'first' }

        expect(transition.send(:constraints_pass?, object)).to eq true

        object.stub(:type) { 'second' }

        expect(transition.send(:constraints_pass?, object)).to eq false
      end

      it 'works with multiple constraints' do
        transition = Wesm::Transition.new(initial: :verified, where: { type: 'first', confirmed: true })
        object.stub(:type) { 'first' }
        object.stub(:confirmed) { true }

        expect(transition.send(:constraints_pass?, object)).to eq true

        object.stub(:confirmed) { false }

        expect(transition.send(:constraints_pass?, object)).to eq false
      end

      it 'works with lambdas in constraints' do
        transition_1 = Wesm::Transition.new(initial: :verified, where: { type: -> (type) { type == 'first' } })
        transition_2 = Wesm::Transition.new(initial: :verified, where: { type: -> (type, object) { type == object.example_field } })
        object.stub(:type) { 'first' }
        object.stub(:example_field) { 'first' }

        expect(transition_1.send(:constraints_pass?, object)).to eq true
        expect(transition_2.send(:constraints_pass?, object)).to eq true

        object.stub(:type) { 'second' }

        expect(transition_1.send(:constraints_pass?, object)).to eq false
        expect(transition_2.send(:constraints_pass?, object)).to eq false
      end
    end
  end

  describe 'private methods' do
    describe '.compare_actor' do
      let(:object) { Object.new }
      let(:user_class) { Class.new(Object) }
      let(:user) { user_class.new }

      before { object.stub(:owner) { user } }

      it 'works with actor defined as Symbol' do
        transition = Wesm::Transition.new(initial: :verified, actor: :owner)
        invalid_user = user_class.new

        expect(transition.send(:compare_actor, :owner, object, user)).to eq true
        expect(transition.send(:compare_actor, :owner, object, invalid_user)).to eq false
      end

      it 'works with actor defined as String' do
        transition = Wesm::Transition.new(initial: :verified, actor: 'owner')
        invalid_user = user_class.new

        expect(transition.send(:compare_actor, :owner, object, user)).to eq true
        expect(transition.send(:compare_actor, :owner, object, invalid_user)).to eq false
      end

      it 'works with actor defined as Class' do
        transition = Wesm::Transition.new(initial: :verified, actor: user_class)
        invalid_user = Class.new(Object).new

        expect(transition.send(:compare_actor, :owner, object, user)).to eq true
        expect(transition.send(:compare_actor, :owner, object, invalid_user)).to eq false
      end
    end
  end
end
