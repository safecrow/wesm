module Wesm
  module Helpers
    module TransitionsHelper
      def successors
        self.class.state_machine.successors(self)
      end

      def show_transitions(actor)
        self.class.state_machine.show_transitions(self, actor)
      end

      def required_fields(to_state)
        self.class.state_machine.required_fields(self, to_state)
      end

      def perform_transition(actor, to_state, options = {})
        self.class.state_machine.perform_transition(self, actor, to_state, options)
      end
    end
  end
end
