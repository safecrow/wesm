module Wesm
  def transition(options)
    @transitions ||= {}
    transition = Transition.new(options)
    (@transitions[transition.from_state] ||= []) << transition.freeze
  end

  def successors(object)
    transitions_for(object).map(&:to_state).uniq
  end

  def show_transitions(object, actor)
    transitions_for(object).map do |transition|
      is_authorized = transition.actor_is_valid?(object, actor)

      {
        to_state: transition.to_state,
        is_authorized: is_authorized,
        can_perform: is_authorized && transition.required_fields_present?(object),
        required_fields: transition.required_fields(object)
      }
    end
  end

  def required_fields(object, to_state)
    transition = get_transition(object, to_state)
    transition && transition.required_fields(object)
  end

  def perform_transition(object, to_state, actor, *extras)
    transition = get_transition!(object, to_state, actor)

    process_transition(object, transition, actor, *extras)
  end

  def process_transition(object, transition, actor, *extras)
    object.public_send("#{state_field}=", transition.to_state)
  end

  private

  def transitions_for(object)
    (@transitions[object.public_send(state_field)] || [])
      .reject { |transition| !transition.valid_scope?(object) }
  end

  def get_transition(object, to_state)
    transitions_for(object).detect { |transition| transition.to_state == to_state }
  end

  def get_transition!(object, to_state, actor)
    transition = get_transition(object, to_state)

    if transition.nil?
      error_desc = "from '#{object.public_send(state_field)}' to '#{to_state}'"
      raise UnexpectedTransitionError.new(error_desc)
    elsif !transition.actor_is_valid?(object, actor)
      error_desc = "for actor: #{actor}"
      raise AccessViolationError.new(error_desc)
    elsif !transition.required_fields_present?(object)
      error_desc = "fields: #{transition.required_fields(object).join(', ')}"
      raise TransitionRequirementError.new(error_desc)
    else
      transition
    end
  end

  def state_field
    :state
  end
end
