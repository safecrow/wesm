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

  it 'provides methods to custom module with correct scope' do
    module CustomModule
      extend Wesm
    end

    public_methods = %i(transition successors show_transitions required_fields
                        perform_transition run_performer_method)
    private_methods = %i(authorized_transitions get_transition get_transition!
                         performers_scope get_performer state_field)

    expect(public_methods.all?(&-> (method) { CustomModule.methods.include?(method) }))
      .to eq true
    expect(private_methods.all?(&-> (method) { CustomModule.private_methods.include?(method) }))
      .to eq true
  end

  it 'has a version number' do
    expect(Wesm::VERSION).not_to be nil
  end
end
