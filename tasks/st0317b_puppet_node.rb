#!/opt/puppetlabs/puppet/bin/ruby

# Puppet Task to interact with Puppet agent nodes
# This can only be run against the Puppet Primary Server.

# Parameters:
#   * agent_certnames - A comma-separated list of agent certificate names.
#   * action - The action passed into `puppet node`.

# Original code by Nate McCurdy
# https://github.com/natemccurdy/puppet-purge_node

require 'puppet'
require 'open3'

Puppet.initialize_settings

# This task only works when running against your Puppet CA server, so let's check for that.
# In Puppetserver, that means that the bootstrap.cfg file contains 'certificate-authority-service'.
bootstrap_cfg = '/etc/puppetlabs/puppetserver/bootstrap.cfg'
if !File.exist?(bootstrap_cfg) || File.readlines(bootstrap_cfg).grep(%r{^[^#].+certificate-authority-service$}).empty?
  puts 'This task can only be run on your certificate authority Puppet Primary Server'
  exit 1
end

def node_action(agent, action)
  stdout, stderr, status = Open3.capture3('/opt/puppetlabs/puppet/bin/puppet', 'node', action, agent)
  {
    stdout: stdout.strip,
    stderr: stderr.strip,
    exit_code: status.exitstatus,
  }
end

results = {}
exit_codes = {}
agents = ENV['PT_agent_certnames'].split(',')
action = ENV['PT_action']

agents.each do |agent|
  results[agent] = {}

  if agent == Puppet[:certname]
    results[agent][:result] = 'Refusing to purge the Puppet Primary Server'
    next
  end

  output = node_action(agent, action)
  exit_codes[agent][:code] = output[:exit_code]
  results[agent][:result] = 
    unless output[:exit_code].zero? 
      output
    else
      case action
      when 'purge'
        'Node Purged'
      when 'deactivate'
        'Node Deactivated'
      else
        "Node Status: #{output[:stdout]}"
      end
    end
end

puts results.to_json

exit(exit_codes.values.all? { |v| v[:code] == 0 }) ? 0 : 1
