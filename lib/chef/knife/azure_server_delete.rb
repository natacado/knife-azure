#
# Author:: Barry Davis (barryd@jetstreamsoftware.com)
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2009-2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path('../azure_base', __FILE__)

# These two are needed for the '--purge' deletion case
require 'chef/node'
require 'chef/api_client'

class Chef
  class Knife
    class AzureServerDelete < Knife

      include Knife::AzureBase

      banner "knife azure server delete SERVER [SERVER] (options)"

      option :purge_os_disk,
        :long => "--purge-os-disk",
        :boolean => true,
        :default => true,
        :description => "Destroy corresponding OS Disk"

      option :purge,
        :short => "-P",
        :long => "--purge",
        :boolean => true,
        :default => false,
        :description => "Destroy corresponding node and client on the Chef Server, in addition to destroying the EC2 node itself.  Assumes node and client have the same name as the server (if not, add the '--node-name' option)."

      option :chef_node_name,
        :short => "-N NAME",
        :long => "--node-name NAME",
        :description => "The name of the node and client to delete, if it differs from the server name.  Only has meaning when used with the '--purge' option."

      # Extracted from Chef::Knife.delete_object, because it has a
      # confirmation step built in... By specifying the '--purge'
      # flag (and also explicitly confirming the server destruction!)
      # the user is already making their intent known.  It is not
      # necessary to make them confirm two more times.
      def destroy_item(klass, name, type_name)
        begin
          object = klass.load(name)
          object.destroy
          ui.warn("Deleted #{type_name} #{name}")
        rescue Net::HTTPServerException
          ui.warn("Could not find a #{type_name} named #{name} to delete!")
        end
      end

      def run

        validate!

        @name_args.each do |name|

          begin
            server = connection.roles.find(name)
            if not server
              ui.warn("Server #{name} does not exist")
              return
            end
            puts "\n"
            msg_pair('Service', server.hostedservicename)
            msg_pair('Deployment', server.deployname)
            msg_pair('Role', server.name)
            msg_pair('Size', server.size)
            msg_pair('SSH Ip Address', server.sshipaddress)
            msg_pair('SSH Port', server.sshport)

            puts "\n"
            confirm("Do you really want to delete this server")
             
            connection.roles.delete(name, params = { :purge_os_disk => locate_config_value(:purge_os_disk) })

            puts "\n"
            ui.warn("Deleted server #{server.name}")

            if config[:purge]
              thing_to_delete = config[:chef_node_name] || name
              destroy_item(Chef::Node, thing_to_delete, "node")
              destroy_item(Chef::ApiClient, thing_to_delete, "client")
            else
              ui.warn("Corresponding node and client for the #{name} server were not deleted and remain registered with the Chef Server")
            end

          rescue Exception => ex
            ui.error("#{ex.message}")
            ui.error("#{ex.backtrace.join("\n")}")
          end
        end
      end

    end
  end
end
