#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:user).provider(:user_role_add)

describe provider_class do
    before do
        @resource = stub("resource", :name => "myuser", :managehome? => nil)
        @resource.stubs(:should).returns "fakeval"
        @resource.stubs(:[]).returns "fakeval"
        @resource.stubs(:allowdupe?).returns false
        @provider = provider_class.new(@resource)
    end

    describe "when calling command" do
        before do
            klass = stub("provider")
            klass.stubs(:command).with(:foo).returns("userfoo")
            klass.stubs(:command).with(:role_foo).returns("rolefoo")
            @provider.stubs(:class).returns(klass)
        end

        it "should use the command if not a role and ensure!=role" do
            @provider.stubs(:is_role?).returns(false)
            @provider.stubs(:exists?).returns(false)
            @resource.stubs(:[]).with(:ensure).returns(:present)
            @provider.command(:foo).should == "userfoo"
        end

        it "should use the role command when a role" do
            @provider.stubs(:is_role?).returns(true)
            @provider.command(:foo).should == "rolefoo"
        end

        it "should use the role command when !exists and ensure=role" do
            @provider.stubs(:is_role?).returns(false)
            @provider.stubs(:exists?).returns(false)
            @resource.stubs(:[]).with(:ensure).returns(:role)
            @provider.command(:foo).should == "rolefoo"
        end
    end

    describe "when calling transition" do
        it "should return the type set to whatever is passed in" do
            @provider.expects(:command).with(:modify).returns("foomod")
            @provider.transition("bar").include?("type=bar")
        end
    end

    describe "when calling create" do
        it "should use the add command when the user is not a role" do
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:addcmd).returns("useradd")
            @provider.expects(:run)
            @provider.create
        end

        it "should use transition(normal) when the user is a role" do
            @provider.stubs(:is_role?).returns(true)
            @provider.expects(:transition).with("normal")
            @provider.expects(:run)
            @provider.create
        end
    end

   describe "when calling destroy" do
       it "should use the delete command if the user exists and is not a role" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:deletecmd)
            @provider.expects(:run)
            @provider.destroy
       end

       it "should use the delete command if the user is a role" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(true)
            @provider.expects(:deletecmd)
            @provider.expects(:run)
            @provider.destroy
       end
   end

   describe "when calling create_role" do
       it "should use the transition(role) if the user exists" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:transition).with("role")
            @provider.expects(:run)
            @provider.create_role
       end

       it "should use the add command when role doesn't exists" do
            @provider.stubs(:exists?).returns(false)
            @provider.expects(:addcmd)
            @provider.expects(:run)
            @provider.create_role
       end
   end

    describe "when allow duplicate is enabled" do
        before do
            @resource.expects(:allowdupe?).returns true
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:execute).with { |args| args.include?("-o") }
        end

        it "should add -o when the user is being created" do
            @provider.create
        end

        it "should add -o when the uid is being modified" do
            @provider.uid = 150
        end
    end

    [:roles, :auths, :profiles].each do |val|
        describe "when getting #{val}" do
            it "should get the user_attributes" do
                @provider.expects(:user_attributes)
                @provider.send(val)
            end

            it "should get the #{val} attribute" do
                attributes = mock("attributes")
                attributes.expects(:[]).with(val)
                @provider.stubs(:user_attributes).returns(attributes)
                @provider.send(val)
            end
        end
    end

    describe "when getting the keys" do
        it "should get the user_attributes" do
            @provider.expects(:user_attributes)
            @provider.keys
        end

        it "should call removed_managed_attributes" do
            @provider.stubs(:user_attributes).returns({ :type => "normal", :foo => "something" })
            @provider.expects(:remove_managed_attributes)
            @provider.keys
        end

        it "should removed managed attribute (type, auths, roles, etc)" do
            @provider.stubs(:user_attributes).returns({ :type => "normal", :foo => "something" })
            @provider.keys.should == { :foo => "something" }
        end
    end

    describe "when adding properties" do
        it "should call build_keys_cmd" do
            @resource.stubs(:should).returns ""
            @resource.expects(:should).with(:keys).returns({ :foo => "bar" })
            @provider.expects(:build_keys_cmd).returns([])
            @provider.add_properties
        end

        it "should add the elements of the keys hash to an array" do
            @resource.stubs(:should).returns ""
            @resource.expects(:should).with(:keys).returns({ :foo => "bar"})
            @provider.add_properties.must == ["-K", "foo=bar"]
        end
    end

    describe "when calling build_keys_cmd" do
        it "should build cmd array with keypairs seperated by -K ending with user" do
            @provider.build_keys_cmd({"foo" => "bar", "baz" => "boo"}).should.eql? ["-K", "foo=bar", "-K", "baz=boo"]
        end
    end

    describe "when setting the keys" do
        before do
            @provider.stubs(:is_role?).returns(false)
        end

        it "should run a command" do
            @provider.expects(:run)
            @provider.keys=({})
        end

        it "should build the command" do
            @resource.stubs(:[]).with(:name).returns("someuser")
            @provider.stubs(:command).returns("usermod")
            @provider.expects(:build_keys_cmd).returns(["-K", "foo=bar"])
            @provider.expects(:run).with(["usermod", "-K", "foo=bar", "someuser"], "modify attribute key pairs")
            @provider.keys=({})
        end
    end
end
