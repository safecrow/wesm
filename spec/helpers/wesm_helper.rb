module WesmHelper
  module_function

  def class_with_wesm
    Class.new do
      extend Wesm
    end
  end

  def object_with_attrs(*attrs)
    _class = Class.new do
      attr_accessor *attrs
    end

    _class.new
  end
end
