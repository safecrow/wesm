module WesmHelper
  module_function

  def class_with_wesm
    Class.new do
      extend Wesm
    end
  end
end
