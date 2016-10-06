module Wesm
  def transition(options)
    @transitions ||= {}
    @transition = Transition.new(options)
    (@transitions[@transition.from_state] ||= []) << @transition.freeze
  end

  def successors(object, actor)
    authorized_transitions(object, actor)
      .map(&-> (transition) { transition.to_state })
  end

  def show_transitions(object, actor)
    authorized_transitions(object, actor).map do |transition|
      {
        to_state: transition.to_state,
        can_perform: transition.required_fields_present?(object),
        required_fields: transition.required_fields
      }
    end
  end

  def required_fields(object, actor, to_state)
    transition = get_transition(object, actor, to_state)
    transition && transition.required
  end

  def perform_transition(object, actor, to_state)
    transition = get_transition!(object, actor, to_state)

    run_performer_method(:before_transition, object, transition)

    object.public_send("#{state_field}=", to_state)
    persist_object(object, transition) if respond_to?(:persist_object)

    run_performer_method(:after_transition, object, transition)
  end

  private

  def run_performer_method(method_name, object, transition)
    return unless transition.performer

    performer = get_performer(transition)

    performer.public_send(method_name, object, transition) \
      if performer.respond_to?(method_name)
  end

  def authorized_transitions(object, actor)
    (@transitions[object.public_send(state_field)] || [])
      .reject(&-> (transition) { !transition.authorized_for?(object, actor) })
  end

  def get_transition(object, actor, to_state)
    authorized_transitions(object, actor)
      .detect(&-> (transition) { transition.to_state == to_state })
  end

  def get_transition!(object, actor, to_state)
    transition = get_transition(object, actor, to_state)

    if transition.present? && transition.required_fields_present?(object)
      transition
    else
      raise AccessViolationError
    end
  end

  def performers_scope
    self
  end

  def get_performer(transition)
    "#{performers_scope}::#{transition.performer.to_s.capitalize}".constantize
  end

  def state_field
    :state
  end
end
