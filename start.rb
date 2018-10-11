require "yaml"
require "fileutils"
require "./num"

repl_port = 33061
image = "davidsiaw/mysqlr"
globaldir = "global"

FileUtils.mkdir_p globaldir
File.write("#{globaldir}/uuid", `uuidgen`.chomp)

for i in 1..num
	dir = "cfg#{i}"
	FileUtils.mkdir_p dir
	#FileUtils.mkdir_p "#{dir}/data1"
	#`chown -R 106:110 #{dir}/data1`
	#FileUtils.mkdir_p "#{dir}/data2"
	#`chown -R 106:110 #{dir}/data2`

	File.write("#{dir}/uuid", `uuidgen`.chomp)

	address = "172.25.2.#{i}"

	mycnf = File.read("my.cnf")
	mycnf.gsub!("{{ uuid }}", File.read("#{globaldir}/uuid"))
	mycnf.gsub!("{{ ip_whitelist }}", (1..num).to_a.map{|x|"172.25.2.#{x}"}.join(","))
	mycnf.gsub!("{{ group_seeds }}", (1..num).to_a.map{|x|"172.25.2.#{x}:#{repl_port}"}.join(","))
	mycnf.gsub!("{{ server_id }}", "#{i}")
	mycnf.gsub!("{{ bind_address }}", address)
	mycnf.gsub!("{{ repl_port }}", "#{repl_port}")
	File.write("#{dir}/my.cnf", mycnf)

	autocnf = File.read("auto.cnf")
	autocnf.gsub!("{{ server_uuid }}", File.read("#{dir}/uuid"))
	File.write("#{dir}/auto.cnf", autocnf)

	certdir = "cfg#{i}/certs"
	subj =  "/C=JP/ST=Tokyo/L=Chiyoda/O=Bunny/CN=astrobunny.net" 
	FileUtils.mkdir_p certdir
	if i == 1
		puts "Generating CA key and root cert"
		`openssl genrsa 2048 > #{globaldir}/ca-key.pem`
		`openssl req -new -x509 -nodes -subj "#{subj}" -days 3600 -key #{globaldir}/ca-key.pem -out #{globaldir}/ca.pem`
	end

	puts "Generating Server #{i} key and cert"
	`openssl req -newkey rsa:2048 -days 3600 -nodes -subj "#{subj}" -keyout #{certdir}/server-key.pem -out #{certdir}/server-req.pem`
	`openssl rsa -in #{certdir}/server-key.pem -out #{certdir}/server-key.pem`
	`openssl x509 -req -in #{certdir}/server-req.pem -days 3600 -CA #{globaldir}/ca.pem -CAkey #{globaldir}/ca-key.pem -set_serial 01 -out #{certdir}/server-cert.pem`

	puts "Generating Client #{i} key and cert"
	`openssl req -newkey rsa:2048 -days 3600 -nodes -subj "#{subj}" -keyout #{certdir}/client-key.pem -out #{certdir}/client-req.pem`
	`openssl rsa -in #{certdir}/client-key.pem -out #{certdir}/client-key.pem`
	`openssl x509 -req -in #{certdir}/client-req.pem -days 3600 -CA #{globaldir}/ca.pem -CAkey #{globaldir}/ca-key.pem -set_serial 01 -out #{certdir}/client-cert.pem`
end

`docker network create -d bridge --subnet 172.25.0.0/16 mysqlnet`
for i in 1..num
	pwd = `pwd`.chomp
	p "#{pwd}/cfg#{i}/my.cnf"

	ca = [
		"ca.pem"
	].map {|x| "-v #{pwd}/#{globaldir}/#{x}:/var/lib/mysql/#{x}"}.join(" ")
	ssl = [
		"client-key.pem",
		"client-cert.pem",
		"server-key.pem",
		"server-cert.pem"
	].map {|x| "-v #{pwd}/#{certdir}/#{x}:/var/lib/mysql/#{x}"}.join(" ")

	`docker run -d --network=mysqlnet -p 3306 -p 33061 -e UID=#{ENV['UID']} --ip=172.25.2.#{i} --name mysql#{i} -v #{pwd}/cfg#{i}/my.cnf:/etc/mysql/my.cnf -v #{pwd}/cfg#{i}/auto.cnf:/var/lib/mysql/auto.cnf #{ca} #{ssl} #{image}`
end

for i in 1..num
	queries = [
		<<-SQL,
			SET SQL_LOG_BIN=0;
			CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword' REQUIRE SSL;
			GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
			FLUSH PRIVILEGES;
			SET SQL_LOG_BIN=1;
		SQL
		"CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpassword' FOR CHANNEL 'group_replication_recovery';",
		"INSTALL PLUGIN group_replication SONAME 'group_replication.so';",
		"SHOW PLUGINS;"

	]

	queries.each do |x|
		puts `docker exec -ti --user root mysql#{i} mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{x.inspect}`
	end
end

for i in 1..1
	queries = [
		"SET GLOBAL group_replication_bootstrap_group=ON;",
		"START GROUP_REPLICATION;",
		"SET GLOBAL group_replication_bootstrap_group=OFF;",
		"SELECT * FROM performance_schema.replication_group_members;"
	]

	queries.each do |x|
		puts `docker exec --user root mysql#{i} mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{x.inspect}`
	end
end

for i in 2..num
	queries = [
		"START GROUP_REPLICATION;",
		"SELECT * FROM performance_schema.replication_group_members;"
	]

	queries.each do |x|
		puts `docker exec --user root mysql#{i} mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{x.inspect}`
	end
end

puts "Starting continuous communication"

def ex(server, command)
	puts `docker exec --user root mysql#{server} mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{command.inspect}`
end

ex(1, "CREATE DATABASE mobs")
ex(1, "CREATE TABLE mobs.porings(id binary(36) not null primary key, name varchar(255), age int)")
