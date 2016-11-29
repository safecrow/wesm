module Wesm
  class BaseError < StandardError; end
  class AccessViolationError < BaseError; end
  class UnexpectedTransitionError < BaseError; end
  class TransitionRequirementError < BaseError; end
end
