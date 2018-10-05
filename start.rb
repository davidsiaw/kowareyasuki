require "yaml"
require "fileutils"

num = 3
repl_port = 33061
image = "davidsiaw/mysqlr"

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
	mycnf.gsub!("{{ uuid }}", File.read("#{dir}/uuid"))
	mycnf.gsub!("{{ ip_whitelist }}", (1..num).to_a.map{|x|"172.25.2.#{x}"}.join(","))
	mycnf.gsub!("{{ group_seeds }}", (1..num).to_a.map{|x|"172.25.2.#{x}:#{repl_port}"}.join(","))
	mycnf.gsub!("{{ server_id }}", "#{i}")
	mycnf.gsub!("{{ bind_address }}", address)
	mycnf.gsub!("{{ repl_port }}", "#{repl_port}")
	File.write("#{dir}/my.cnf", mycnf)

	pwd = `pwd`.chomp
	`docker run -ti --user root -v #{pwd}/cfg#{i}/data1:/var/lib/mysql #{image} chown -R mysql:mysql /var/lib/mysql`
	`docker run -ti --user mysql -v #{pwd}/cfg#{i}/data1:/var/lib/mysql #{image} mysql_ssl_rsa_setup --uid=mysql --datadir=/var/lib/mysql`
end

`docker network create -d bridge --subnet 172.25.0.0/16 mysqlnet`
for i in 1..num
	pwd = `pwd`.chomp
	p "#{pwd}/cfg#{i}/my.cnf"

	ssl = [
		"client-key.pem",
		"client-cert.pem",
		"server-key.pem",
		"server-cert.pem",
		"private_key.pem",
		"public_key.pem"
	].map {|x| "-v #{pwd}/cfg#{i}/data1/#{x}:/var/lib/mysql/#{x}"}.join(" ")
	`docker run -d --network=mysqlnet -p 3306 -p 33061 -e UID=#{ENV['UID']} --ip=172.25.2.#{i} --name mysql#{i} -v #{pwd}/cfg#{i}/my.cnf:/etc/mysql/my.cnf #{ssl} #{image}`
end

for i in 1..num
	queries = [
		"SET SQL_LOG_BIN=0;",
		"CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword' REQUIRE SSL;",
		"GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';",
		"FLUSH PRIVILEGES;",
		"SET SQL_LOG_BIN=1;",
		"CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpassword' FOR CHANNEL 'group_replication_recovery';",
		"INSTALL PLUGIN group_replication SONAME 'group_replication.so';",
		"SHOW PLUGINS;"

	]

	queries.each do |x|
		puts `docker exec --user root mysql1 mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{x.inspect}`
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
		puts `docker exec --user root mysql1 mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{x.inspect}`
	end
end

for i in 2..num
	queries = [
		"START GROUP_REPLICATION;",
		"SELECT * FROM performance_schema.replication_group_members;"
	]

	queries.each do |x|
		puts `docker exec --user root mysql1 mysql --socket=/var/run/mysqld/mysqld.sock -u root -e #{x.inspect}`
	end
end