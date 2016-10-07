module Wesm
  class Transition
    attr_accessor :from_state, :to_state, :performer, :required_fields

    def initialize(options)
      @from_state = options.keys.first.to_s
      @to_state = options.values.first.to_s
      @allowed_actors = options[:actor]
      @constraints = options[:where]
      @required_fields = Array(options[:required])
      @performer = options[:performer]
    end

    def permited_for?(object, actor)
      actor_is_valid?(object, actor) && constraints_pass?(object)
    end

    def required_fields_present?(object)
      @required_fields.each do |required_field|
        return false if object.public_send(required_field).nil?
      end
      true
    end

    def to_h
      {
        to_state: @to_state,
        from_state: @from_state,
        actor: @allowed_actors,
        where: @constraints,
        required: @required_fields,
        performer: @performer
      }
    end

    private

    def actor_is_valid?(object, actor)
      return true unless @allowed_actors

      if @allowed_actors.is_a? Array
        @allowed_actors.map { |allowed_actor| compare_actor(allowed_actor, object, actor) }.any?
      else
        compare_actor(@allowed_actors, object, actor)
      end
    end

    def constraints_pass?(object)
      @constraints.to_h.each do |field, value|
        return false unless \
          begin
            if value.is_a? Proc
              if value.arity == 1
                value.call(object.public_send(field))
              elsif value.arity == 2
                value.call(object.public_send(field), object)
              else
                raise ArgumentError.new('Proc in \'where\' condition can only take 1 or 2 args')
              end
            else
              object.public_send(field) == value
            end
          end
      end
      true
    end

    def compare_actor(allowed_actor, object, actor)
      if allowed_actor.is_a? Class
        allowed_actor === actor
      elsif allowed_actor.is_a?(Symbol) || allowed_actor.is_a?(String)
        object.public_send(allowed_actor) == actor
      else
        raise ArgumentError.new('Transition actor must be a kind of Class, String or Symbol')
      end
    end
  end
end
