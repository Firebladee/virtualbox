require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')

class RelatableTest < Test::Unit::TestCase
  class Relatee
    def self.populate_relationship(caller, data)
      "FOO"
    end
  end
  class BarRelatee
    def self.set_relationship(caller, old_value, new_value)
    end
  end

  class EmptyRelatableModel
    include VirtualBox::AbstractModel::Relatable
  end

  class RelatableModel < EmptyRelatableModel
    relationship :foos, Relatee
    relationship :bars, BarRelatee
  end

  setup do
    @data = {}
  end

  context "class methods" do
    should "read back relationships in order added" do
      order = mock("order")
      order_seq = sequence("order_seq")
      order.expects(:foos).in_sequence(order_seq)
      order.expects(:bars).in_sequence(order_seq)

      RelatableModel.relationships.each do |name, options|
        order.send(name)
      end
    end
  end

  context "setting a relationship" do
    setup do
      @model = RelatableModel.new
    end

    should "have a magic method relationship= which calls set_relationship" do
      @model.expects(:set_relationship).with(:foos, "FOOS!")
      @model.foos = "FOOS!"
    end

    should "raise a NonSettableRelationshipException if relationship can't be set" do
      assert_raises(VirtualBox::Exceptions::NonSettableRelationshipException) {
        @model.foos = "FOOS!"
      }
    end

    should "call set_relationship on the relationship class" do
      BarRelatee.expects(:populate_relationship).returns("foo")
      @model.populate_relationships({})

      BarRelatee.expects(:set_relationship).with(@model, "foo", "bars")
      assert_nothing_raised { @model.bars = "bars" }
    end

    should "set the result of set_relationship as the new relationship data" do
      BarRelatee.stubs(:set_relationship).returns("hello")
      @model.bars = "zoo"
      assert_equal "hello", @model.bars
    end
  end

  context "subclasses" do
    class SubRelatableModel < RelatableModel
      relationship :bars, RelatableTest::Relatee
    end

    setup do
      @relationships = SubRelatableModel.relationships
    end

    should "inherit relationships of parent" do
      assert SubRelatableModel.has_relationship?(:foos)
      assert SubRelatableModel.has_relationship?(:bars)
    end

    should "inherit options of relationships" do
      assert_equal Relatee, SubRelatableModel.relationships_hash[:foos][:klass]
    end
  end

  context "default callbacks" do
    setup do
      @model = RelatableModel.new
    end

    should "not raise an error if populate_relationship doesn't exist" do
      assert !BarRelatee.respond_to?(:populate_relationship)
      assert_nothing_raised { @model.populate_relationships(nil) }
    end

    should "not raise an error when saving relationships if the callback doesn't exist" do
      assert !Relatee.respond_to?(:save_relationship)
      assert_nothing_raised { @model.save_relationships }
    end

    should "not raise an error in destroying relationships if the callback doesn't exist" do
      assert !Relatee.respond_to?(:destroy_relationship)
      assert_nothing_raised { @model.destroy_relationships }
    end
  end

  context "destroying" do
    setup do
      @model = RelatableModel.new
      @model.populate_relationships({})
    end

    context "a single relationship" do
      should "call destroy_relationship only for the given relationship" do
        Relatee.expects(:destroy_relationship).once
        BarRelatee.expects(:destroy_relationship).never
        @model.destroy_relationship(:foos)
      end

      should "forward any args passed into destroy_relationship" do
        Relatee.expects(:destroy_relationship).with(@model, anything, "HELLO").once
        @model.destroy_relationship(:foos, "HELLO")
      end

      should "pass the data into destroy_relationship" do
        Relatee.expects(:destroy_relationship).with(@model, "FOO").once
        @model.destroy_relationship(:foos)
      end

      should "call read_relationship (to force the load if lazy)" do
        Relatee.expects(:destroy_relationship).with(@model, "FOO").once
        @model.expects(:read_relationship).with(:foos).once
        @model.destroy_relationship(:foos)
      end
    end

    context "all relationships" do
      should "call destroy_relationship on the related class" do
        Relatee.expects(:destroy_relationship).with(@model, anything).once
        @model.destroy_relationships
      end

      should "forward any args passed into destroy relationships" do
        Relatee.expects(:destroy_relationship).with(@model, anything, "HELLO").once
        @model.destroy_relationships("HELLO")
      end
    end
  end

  context "lazy relationships" do
    class LazyRelatableModel < EmptyRelatableModel
      relationship :foos, Relatee, :lazy => true
      relationship :bars, BarRelatee
    end

    setup do
      @model = LazyRelatableModel.new
    end

    should "return true if a relationship is lazy, and false if not, when checking" do
      assert @model.lazy_relationship?(:foos)
      assert !@model.lazy_relationship?(:bars)
    end

    should "not be loaded by default" do
      assert !@model.loaded_lazy_relationship?(:foos)
    end

    should "be able to mark a relationship as loaded" do
      @model.loaded_lazy_relationship!(:foos)
      assert @model.loaded_lazy_relationship?(:foos)
    end

    should "call `load_relationship` on initial load" do
      @model.expects(:load_relationship).with(:foos).once
      @model.foos
    end

    should "not call `load_relationship` for non lazy attributes" do
      @model.expects(:load_relationship).never
      @model.bars
    end

    should "mark a relationship as loaded on populate_relationship" do
      @model.populate_relationship(:foos, {})
      assert @model.loaded_lazy_relationship?(:foos)
    end
  end

  context "saving relationships" do
    setup do
      @model = RelatableModel.new
    end

    should "call save_relationship on the related class" do
      Relatee.expects(:save_relationship).with(@model, @model.foos).once
      @model.save_relationships
    end

    should "forward parameters through" do
      Relatee.expects(:save_relationship).with(@model, @model.foos, "YES").once
      @model.save_relationships("YES")
    end
  end

  context "reading relationships" do
    setup do
      @model = RelatableModel.new
    end

    should "provide a read method for relationships" do
      assert_nothing_raised { @model.foos }
    end
  end

  context "checking for relationships" do
    setup do
      @model = RelatableModel.new
    end

    should "have a class method as well" do
      assert RelatableModel.has_relationship?(:foos)
      assert !RelatableModel.has_relationship?(:bazs)
    end

    should "return true for existing relationships" do
      assert @model.has_relationship?(:foos)
    end

    should "return false for nonexistent relationships" do
      assert !@model.has_relationship?(:bazs)
    end
  end

  context "populating relationships" do
    setup do
      @model = RelatableModel.new
    end

    should "be able to populate a single relationship" do
      Relatee.expects(:populate_relationship).with(@model, @data).once
      @model.populate_relationship(:foos, @data)
    end

    should "call populate_relationship on the related class" do
      populate_seq = sequence("populate_seq")
      @model.expects(:populate_relationship).with(:foos, @data).once.in_sequence(populate_seq)
      @model.expects(:populate_relationship).with(:bars, @data).once.in_sequence(populate_seq)
      @model.populate_relationships(@data)
    end

    should "properly save returned value as the value for the relationship" do
      Relatee.expects(:populate_relationship).once.returns("HEY")
      @model.populate_relationships(@data)
      assert_equal "HEY", @model.foos
    end
  end
end