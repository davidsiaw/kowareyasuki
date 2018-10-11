require "yaml"
require "fileutils"
require "pry"

class GuiltyFile
	attr_reader :server_types

	def initialize(file)
		@server_types = {}
		eval_file(file)
	end
	
	def eval_file(file)
		instance_eval File.read(file), file
	end

	def server(type:, &block)
		@server_types[type] = Proc.new(&block)
	end
end

class Server

	def initialize(proc:, server_number:, server_ip:, other_servers:)
		@image = "alpine"
		@files = {}
		@name = nil
		instance_exec(server_number, server_ip, other_servers, &proc)
	end

	def file(named:, template:nil, vars:{}, contents:nil)

	end

	def image(name)
		@image = name

		if name.is_a? Symbol
			# cd images/#{symbol}
			# docker build
		else
			# docker pull name
		end
	end
end

class Test

	def initialize(setup_name:,layout:)
		@init_dir = `pwd`.chomp
		@setup_name = setup_name
		@layout = layout

		@all_servers = {}
		@guilty_file = nil
		@servers = {}
	end

	def base_dir
		"#{@init_dir}/.test_artifacts"
	end

	def global_dir
		"#{base_dir}/global"
	end

	def server_key(type:,number:)
		"#{type}_#{number}"
	end

	def instance_dir(type:,number:)
		"#{base_dir}/#{server_key(type: type, number: number)}"
	end

	def start
		`docker network create -d bridge --subnet 172.25.0.0/16 testnet`
		FileUtils.mkdir_p global_dir
		c = 1
		@layout.each do |k,v|
			@all_servers[k] = {}
			for i in 1..v
				c += 1
				ip_address = "172.25.2.#{c}"
				@all_servers[k][i] = {
					server_number: i,
					server_ip: ip_address
				}
				FileUtils.mkdir_p instance_dir(type: k, number: i)
			end
		end
 
		Dir.chdir global_dir
		@guilty_file = GuiltyFile.new("#{@init_dir}/setups/#{@setup_name}/GuiltyFile")
		Dir.chdir @init_dir

		@layout.each do |k,v|
			for i in 1..v
				Dir.chdir instance_dir(type: k, number: i)
				@servers[server_key(type: k, number: i)] = Server.new(
					proc: @guilty_file.server_types[k],
					server_number: i,
					server_ip: @all_servers[k][i][:server_ip],
					other_servers: @all_servers)
				Dir.chdir @init_dir
			end
		end
	end

	def stop
		`docker network rm testnet`
		FileUtils.rm_rf(base_dir)
	end
end

test = Test.new setup_name: "mysql-group-replication", 
      layout: {
      	master: 5
      }

test.send(:"#{ARGV.shift}")