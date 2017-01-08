module Wesm
  class Transition
    attr_accessor :from_state, :to_state, :performer, :required

    def initialize(options, performer_scope = nil)
      @from_state = options.keys.first.to_s
      @to_state = options.values.first.to_s
      @valid_actors = Array(options[:actor])
      @scope = options[:scope]
      @required = Array(options[:required])
      @performer = get_performer(options[:performer], performer_scope)
    end

    def actor_is_valid?(object, actor)
      @valid_actors.empty? || \
        @valid_actors.map { |valid_actor| compare_actor(valid_actor, object, actor) }.any?
    end

    def required_fields(object)
      @required.select { |required_field| object.public_send(required_field).nil? }
    end

    def required_fields_present?(object)
      @required.each do |required_field|
        return false if object.public_send(required_field).nil?
      end
      true
    end

    def valid_scope?(object)
      @scope.to_h.each do |field, value|
        return false unless \
          begin
            if value.is_a? Proc
              value.call(*[object.public_send(field), object][0...value.arity])
            else
              object.public_send(field) == value
            end
          end
      end
      true
    end

    private

    def compare_actor(valid_actor, object, actor)
      if [String, Symbol].include? valid_actor.class
        object.public_send(valid_actor) == actor
      elsif valid_actor.is_a? Class
        if actor.is_a?(Class)
          actor == valid_actor
        else
          actor.is_a?(valid_actor)
        end
      else
        false
      end
    end

    def get_performer(performer_name, performer_scope)
      return unless performer_name

      performer_name = "#{performer_scope}::#{performer_name}" if performer_scope
      self.class.const_get(performer_name)
    rescue NameError; end
  end
end
