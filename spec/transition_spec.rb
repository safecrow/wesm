require 'spec_helper'

describe Wesm::Transition do
  let(:object) { Object.new }

  describe 'public methods' do
    describe '.actor_is_valid?' do
      let(:user_class) { Class.new }

      it 'works with single actor' do
        transition = Wesm::Transition.new initial: :success, actor: :owner

        user = user_class.new
        invalid_user = user_class.new

        object.stub(:owner) { user }

        expect(transition.actor_is_valid?(object, user)).to eq true
        expect(transition.actor_is_valid?(object, invalid_user)).to eq false
      end

      it 'works with multiple actors' do
        transition = Wesm::Transition.new initial: :success, actor: [:owner, :watcher]

        user = user_class.new
        second_user = user_class.new
        invalid_user = user_class.new

        object.stub(:owner) { user }
        object.stub(:watcher) { second_user }

        expect(transition.actor_is_valid?(object, user)).to eq true
        expect(transition.actor_is_valid?(object, second_user)).to eq true
        expect(transition.actor_is_valid?(object, invalid_user)).to eq false
      end
    end

    describe '.required_fields' do
      it 'shows nil required fields for object' do
        transition = Wesm::Transition.new initial: :success, required: [:info, :agreement]
        transition2 = Wesm::Transition.new initial: :done

        object = WesmHelper.object_with_attrs :info, :agreement

        expect(transition.required_fields(object)).to eq [:info, :agreement]

        object.agreement = 'value'

        expect(transition.required_fields(object)).to eq [:info]
        expect(transition2.required_fields(object)).to eq []
      end
    end

    describe '.required_fields_present?' do
      it 'checks for all required fields presence' do
        transition = Wesm::Transition.new initial: :success, required: [:info, :agreement]
        transition2 = Wesm::Transition.new initial: :success

        object.stub(:info) { 'value' }
        object.stub(:agreement)

        expect(transition.required_fields_present?(object)).to eq false
        expect(transition2.required_fields_present?(object)).to eq true

        object.stub(:agreement) { 'value' }

        expect(transition.required_fields_present?(object)).to eq true
      end
    end

    describe '.valid_scope?' do
      it 'works with single constraint' do
        transition = Wesm::Transition.new initial: :success, scope: { type: 'first' }

        object = WesmHelper.object_with_attrs :type

        expect(transition.valid_scope?(object)).to eq false

        object.stub(:type) { 'first' }

        expect(transition.valid_scope?(object)).to eq true

        object.stub(:type) { 'second' }

        expect(transition.valid_scope?(object)).to eq false
      end

      it 'works with multiple constraints' do
        transition = Wesm::Transition.new initial: :success, scope: { type: 'first', confirmed: true }

        object.stub(:type) { 'first' }
        object.stub(:confirmed) { true }

        expect(transition.valid_scope?(object)).to eq true

        object.stub(:confirmed) { false }

        expect(transition.valid_scope?(object)).to eq false
      end

      it 'works with lambdas in constraints' do
        transition = Wesm::Transition.new initial: :success, scope: { type: -> (type) { type == 'first' } }
        transition2 = Wesm::Transition.new initial: :success, scope: { type: -> (type, object) { type == object.example_field } }

        object.stub(:type) { 'first' }
        object.stub(:example_field) { 'first' }

        expect(transition.valid_scope?(object)).to eq true
        expect(transition2.valid_scope?(object)).to eq true

        object.stub(:type) { 'second' }

        expect(transition.valid_scope?(object)).to eq false
        expect(transition2.valid_scope?(object)).to eq false
      end
    end
  end

  describe 'private methods' do
    describe '.compare_actor' do
      let(:user_class) { Class.new(Object) }

      it 'works with valid actor defined as Symbol' do
        transition = Wesm::Transition.new initial: :success

        user = user_class.new
        invalid_user = user_class.new

        object.stub(:owner) { user }

        expect(transition.send(:compare_actor, :owner, object, user)).to eq true
        expect(transition.send(:compare_actor, :owner, object, invalid_user)).to eq false
      end

      it 'works with valid actor defined as String' do
        transition = Wesm::Transition.new initial: :success

        user = user_class.new
        invalid_user = user_class.new

        object.stub(:owner) { user }

        expect(transition.send(:compare_actor, 'owner', object, user)).to eq true
        expect(transition.send(:compare_actor, 'owner', object, invalid_user)).to eq false
      end

      it 'works with valid actor defined as Class' do
        transition = Wesm::Transition.new initial: :success

        user = user_class.new
        invalid_user = Object.new

        object.stub(:owner) { user }

        expect(transition.send(:compare_actor, user_class, object, user)).to eq true
        expect(transition.send(:compare_actor, user_class, object, invalid_user)).to eq false
      end

      it 'works if actor is a class itself' do
        transition = Wesm::Transition.new initial: :success

        expect(transition.send(:compare_actor, user_class, object, user_class)).to eq true
      end
    end

    describe '.get_performer' do
      let(:transition) { transition = Wesm::Transition.new initial: :success }

      it 'returns nil if performer not defined for transition' do
        expect(transition.send(:get_performer, nil, nil)).to eq nil
      end

      it 'returns performer constant if performer name is defined and valid' do
        class SomeClass; end

        expect(transition.send(:get_performer, 'SomeClass', nil)).to eq SomeClass

        Object.send(:remove_const, :SomeClass)
      end

      it 'returns nil if performer name is defined but not valid' do
        expect(transition.send(:get_performer, 'SomeClass', nil)).to eq nil
      end

      it 'returns performer constant if name is defined with scope' do
        module Wrapper
          class SomeClass; end
        end

        expect(transition.send(:get_performer, 'SomeClass', 'Wrapper')).to eq Wrapper::SomeClass

        Object.send(:remove_const, :Wrapper)
      end
    end
  end
end
