module Fog
  module Compute
    class VcloudDirector
      class Real
        # Create a vApp from a vApp template.
        #
        # The response includes a Task element. You can monitor the task to to
        # track the creation of the vApp.
        #
        # @param [String] vapp_name
        # @param [String] template_id
        # @param [Hash] options
        # @return [Excon::Response]
        #   * body<~Hash>:
        # @see http://pubs.vmware.com/vcd-51/topic/com.vmware.vcloud.api.reference.doc_51/doc/operations/POST-InstantiateVAppTemplate.html
        #   vCloud API Documentaion
        # @since vCloud API version 0.9
        # @todo Replace with #post_instantiate_vapp_template
        def instantiate_vapp_template(vapp_name, template_id, options={})
          params = populate_uris(options.merge(:vapp_name => vapp_name, :template_id => template_id))
          validate_uris(params)

          # @todo Move all the logic to a generator.
          data = generate_instantiate_vapp_template_request(params)

          request(
            :body    => data,
            :expects => 201,
            :headers => {'Content-Type' => 'application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml'},
            :method  => 'POST',
            :parser  => Fog::ToHashDocument.new,
            :path    => "vdc/#{params[:vdc_id]}/action/instantiateVAppTemplate"
          )
        end

        private

        def validate_uris(options={})
          [:vdc_uri, :network_uri].each do |opt_uri|
            result = default_organization_body[:Link].detect {|org| org[:href] == options[opt_uri]}
            raise("#{opt_uri}: #{options[opt_uri]} not found") unless result
          end
        end

        def populate_uris(options = {})
          options[:vdc_id] ||= default_vdc_id
          options[:vdc_uri] =  vdc_end_point(options[:vdc_id])
          options[:network_id] ||= default_network_id
          options[:network_uri] = network_end_point(options[:network_id])
          #options[:network_name] = default_network_name || raise("error retrieving network name")
          options[:template_uri] = vapp_template_end_point(options[:template_id]) || raise(":template_id option is required")
          #customization_options = get_vapp_template(options[:template_uri]).body[:Children][:Vm][:GuestCustomizationSection]
          ## Check to see if we can set the password
          #if options[:password] and customization_options[:AdminPasswordEnabled] == "false"
          #  raise "The catalog item #{options[:catalog_item_uri]} does not allow setting a password."
          #end
          #
          ## According to the docs if CustomizePassword is "true" then we NEED to set a password
          #if customization_options[:AdminPasswordEnabled] == "true" and customization_options[:AdminPasswordAuto] == "false" and ( options[:password].nil? or options[:password].empty? )
          #  raise "The catalog item #{options[:catalog_item_uri]} requires a :password to instantiate."
          #end
          options
        end

        def generate_instantiate_vapp_template_request(options ={})
          xml = Builder::XmlMarkup.new
          xml.InstantiateVAppTemplateParams(xmlns.merge!(:name => options[:vapp_name], :"xml:lang" => "en")) {
            xml.Description(options[:description])
            xml.InstantiationParams {
              # This options are fully ignored
              if options[:network_uri]
                xml.NetworkConfigSection {
                  xml.tag!("ovf:Info"){ "Configuration parameters for logical networks" }
                  xml.NetworkConfig("networkName" => options[:network_name]) {
                    xml.Configuration {
                      xml.ParentNetwork(:href => options[:network_uri])
                      xml.FenceMode("bridged")
                    }
                  }
                }
              end
            }
            # The template
            xml.Source(:href => options[:template_uri])
            xml.AllEULAsAccepted("true")
          }
        end

        def xmlns
          {
            'xmlns'     => "http://www.vmware.com/vcloud/v1.5",
            "xmlns:ovf" => "http://schemas.dmtf.org/ovf/envelope/1",
            "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
            "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema"
          }
        end
      end
    end
  end
end
