module MockConstructor
  class MockObject; end

  module_function

  def object_with_attr_accessors(*attrs)
    _class = Class.new(MockObject) do
      attr_accessor *attrs
    end

    _class.new
  end
end
