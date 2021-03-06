require 'thor'
require 'thor/aws'

module Sgupdater
  class CLI < Thor
    include Thor::Aws

    class_option :verbose, type: :boolean, default: false, aliases: [:v]

    desc :show, "Show current permissions"
    method_option :from_cidr, type: :string, required: true
    method_option :to_cidr, type: :string, required: false
    method_option :show_account, type: :boolean, required: false, default: false
    def show
      client.get.each {|sg| show_security_groups(sg, options[:from_cidr], options[:to_cidr])}
    end

    desc :update, "Update cidr address"
    method_option :from_cidr, type: :string, required: true
    method_option :to_cidr, type: :string, required: true
    def update
      updated = client.update
      if updated
        puts "Update success"
      else
        puts "No change"
      end
    end

    desc :add, "Add to_cidr address same from_cidr setting"
    method_option :from_cidr, type: :string, required: true
    method_option :to_cidr, type: :string, required: true
    def add
      added = client.add
      if added
        puts "Add success"
      else
        puts "No change"
      end
    end

    private
    def client
      @client ||= Client.new options, aws_configuration
    end

    def cidr_in_ip_permission?(ip_permission, cidr)
      ip_permission.ip_ranges.select {|ip| ip.values.include? cidr}.size > 0
    end

    def cidr1_in_ip_permission_and_cidr2_not_in_ip_permission?(ip_permission, cidr1, cidr2)
       cidr1_find = cidr_in_ip_permission?(ip_permission, cidr1)
       cidr2_not_find = !cidr_in_ip_permission?(ip_permission, cidr2)
       cidr1_find && cidr2_not_find
    end

    def ip_ranges_to_ips(ip_ranges)
      ip_ranges.map {|ip_range| ip_range.values}.flatten
    end

    def show_security_groups(sg, from_cidr, to_cidr)
      sg.ip_permissions.each do |perm|
        found = false
        if to_cidr
          found = cidr1_in_ip_permission_and_cidr2_not_in_ip_permission?(perm, from_cidr, to_cidr)
        else
          found = cidr_in_ip_permission?(perm, from_cidr)
        end

        if found
          print "#{sg.owner_id}\t" if options[:show_account]
          puts [aws_configuration[:region], sg.vpc_id || '(classic)', sg.group_id, sg.group_name, perm.from_port, perm.to_port, ip_ranges_to_ips(perm.ip_ranges).join(",")].join("\t")
        end
      end
    end
  end
end

