require 'puppet/resource_reference'

# A reference to a resource.  Mostly just the type and title.
class Puppet::Parser::Resource::Reference < Puppet::ResourceReference
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors

    attr_accessor :builtin, :file, :line, :scope

    # Are we a builtin type?
    def builtin?
        unless defined? @builtin
            if builtintype()
                @builtin = true
            else
                @builtin = false
            end
        end

        @builtin
    end

    def builtintype
        if t = Puppet::Type.type(self.type.downcase) and t.name != :component
            t
        else
            nil
        end
    end

    # Return the defined type for our obj.  This can return classes,
    # definitions or nodes.
    def definedtype
        unless defined? @definedtype
            case self.type
            when "Class": # look for host classes
                if self.title == :main
                    tmp = @scope.findclass("")
                else
                    unless tmp = @scope.findclass(self.title)
                        fail Puppet::ParseError, "Could not find class '%s'" % self.title
                    end
                end
            when "Node": # look for node definitions
                unless tmp = @scope.parser.nodes[self.title]
                    fail Puppet::ParseError, "Could not find node '%s'" % self.title
                end
            else # normal definitions
                # We have to swap these variables around so the errors are right.
                tmp = @scope.finddefine(self.type)
            end

            if tmp
                @definedtype = tmp
            else
                fail Puppet::ParseError, "Could not find resource type '%s'" % self.type
            end
        end

        @definedtype
    end

    def initialize(hash)
        set_options(hash)
        requiredopts(:type, :title)
    end

    def to_ref
        # We have to return different cases to provide backward compatibility
        # from 0.24.x to 0.23.x.
        if builtin?
            return [type.to_s.downcase, title.to_s]
        else
            return [type.to_s, title.to_s]
        end
    end

    def typeclass
        unless defined? @typeclass
            if tmp = builtintype || definedtype
                @typeclass = tmp
            else
                fail Puppet::ParseError, "Could not find type %s" % self.type
            end
        end

        @typeclass
    end
end
