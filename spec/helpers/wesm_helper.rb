module WesmHelper
  module_function

  def module_with_wesm
    Module.new do
      extend Wesm
    end
  end
end
