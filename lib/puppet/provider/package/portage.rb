require 'puppet/provider/package'

Puppet::Type.type(:package).provide :portage, :parent => Puppet::Provider::Package do
    desc "Provides packaging support for Gentoo's portage system."

    has_feature :versionable

    commands :emerge => "/usr/bin/emerge", :equery => '/usr/bin/equery'

    defaultfor :operatingsystem => :gentoo
   
    confine :operatingsystem => :gentoo
 
    PACKAGE_VERSION_REGEXP = /\d[0-9.]*[a-z]?(?:_(?:alpha|beta|pre|rc|p)[0-9]*)*(?:-r\d+)?/

    def self.instances
        packages = parse_equery_output(equery '-C', 'l')
        packages = fill_version_available(packages)

        packages.values.map { |p| new(p) }
    end
    
    def self.parse_equery_output(search_output)
        result_format = /(\S+)\/(\S+)-(#{PACKAGE_VERSION_REGEXP})/
        result_fields = [:category, :name, :ensure]

        packages = {}
        search_output.each do |search_result|
            match = result_format.match( search_result )

            if match
                package = {}
                result_fields.zip(match.captures) { |field, value|
                    package[field] = value unless !value or value.empty?
                }
                package[:provider] = :portage
                package[:ensure] = package[:ensure].split.last

                packages["%s/%s" % [package[:category], package[:name]]] = package
            end
        end
        
        packages
    rescue Puppet::ExecutionFailure => detail
        rause Puppet::Error.new(detail)
    end
    
    def self.fill_version_available(packages)
        result_format = /(\S+)\/(\S+)-(#{PACKAGE_VERSION_REGEXP}) (?:\[(#{PACKAGE_VERSION_REGEXP})\])?/
        result_fields = [:category, :name, :ensure, :version_available]

        begin
            search_output = emerge '--nodeps', '-p', *(packages.values.map { |p| "%s/%s" % [p[:category], p[:name]] })
            
            search_output.each do |search_result|
                match = result_format.match( search_result )

                if match
                    packages["%s/%s" % [match[1], match[2]]][:version_available] = match[4] || match[3]
                end
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new(detail)
        end

        packages
    end

    def install
        should = @resource.should(:ensure)
        name = package_name
        unless should == :present or should == :latest
            # We must install a specific version
            name = "=%s-%s" % [name, should]
        end
        emerge name
    end

    # The common package name format.
    def package_name
        @resource[:category] ? "%s/%s" % [@resource[:category], @resource[:name]] : @resource[:name]
    end

    def uninstall
        emerge "--unmerge", package_name
    end

    def update
        self.install
    end

    def query
        packages = self.class.parse_equery_output(equery '-C', 'l', package_name)

        if packages.size == 0
            not_found_value = "%s/%s" % [@resource[:category] ? @resource[:category] : "<unspecified category>", @resource[:name]]
            raise Puppet::Error.new("No package found with the specified name [#{not_found_value}]")
        end
        
        if packages.size > 1
            raise Puppet::Error.new("More than one package with the specified name [#{search_value}], please use the category parameter to disambiguate")
        end
        
        packages = self.class.fill_version_available(packages)
        
        packages.values[0]
    end

    def latest
        return self.query[:version_available]
    end
end
