#!/usr/bin/env ruby

require 'bunny'
require 'json'
require 'xenapi.rb'

require_relative 'messages'

# Class: Rabbit
# A class to manage the DNS AMQP API
class Rabbit
  # initialize by define and start connection
  def initialize
    @connection = Bunny.new(ENV['AMQP_URI'] || 'amqp://localhost')
    @connection.start
    @channel = @connection.create_channel
  end

  # Core
  def start
    puts ' [!] Waiting for messages. To exit press CTRL+C'
    begin
      queue_in.subscribe(block: true) do |_, properties, body|
        Thread.new { Processor.process(body, properties.correlation_id) }
      end
    rescue Interrupt => _
      @channel.close
      @connection.close
    end
  end

  # Message Queue Publisher
  def publish(message, corr)
    @channel.default_exchange.publish(message, routing_key: queue_out.name, correlation_id: corr)
    puts ' [x] SENT @ #{corr}'
    @channel.close
    @connection.close
  end

  private

  # Set up the ingoing queue
  def queue_in
    @channel.queue('hypervisor', durable: true)
  end

  # Set up the outgoing queue
  def queue_out
    @channel.queue('out', durable: true)
  end
end

# Class: Processor
# The main work logic.
class Processor
  # Process the Stuff.
  def self.process(body, msg_id)
    xenapi = XenApi.new
    rabbit = Rabbit.new
    parsed = JSON.parse(body)
    payload = parsed['payload']
    puts ' [x] Task : ' + parsed['task']
    msg = {
      seq: parsed['id'],
      taskid: parsed['uuid'],
      timestamp: Time.now.getutc.to_s,
      payload: case parsed['task']
               when 'get.vms'
                 xenapi.all_vm
               when 'get.vm_detail'
                 xenapi.vm_record(payload)
               when 'get.vm_more_detail'
                 xenapi.inspect_vm(payload)
               when 'get.vm_network'
                 xenapi.inspect_vm_network(payload, 'all')
               when 'get.vm_network_ip4'
                 xenapi.inspect_vm_network(payload, 4)
               when 'get.vm_network_ip6'
                 xenapi.inspect_vm_network(payload, 6)
               when 'set.vm_power_on'
                 xenapi.vm_power_on(payload)
               when 'set.vm_power_off'
                 xenapi.vm_power_off(payload)
               when 'set.vm_power_reboot'
                 xenapi.vm_power_reboot(payload)
               else
                 Messages.error_undefined
               end
    }
    rabbit.publish(JSON.generate(msg), msg_id)
    xenapi.logout
  end
end

rabbit = Rabbit.new
rabbit.start
