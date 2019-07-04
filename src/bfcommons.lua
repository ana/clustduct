#!/usr/bin/lua
-- simple print function for tables
function tprint (t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) ..'"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"'.. tostring(v) ..'"'
        if type(v) == 'table' then
            tprint(v, (s or '')..kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            print(type(t)..(s or '')..kfmt..' = '..vfmt)
        end
    end
end
-- common lua pxe/efi file functions is called from clustuct
-- and clustuctbf

function create_entry_pxe(entry,name)
	name = name or "Boot_to_the_unknown"
	ret_str = ""
	ret_str = ret_str.."LABEL "..name.."\n"
	if entry["menu"] ~= nil then 
		ret_str = ret_str.."\tMENU LABEL "..entry["menu"].."\n"
	else
		ret_str = ret_str.."\tMENU LABEL "..name.."\n"
	end
	if entry["com32"] ~= nil then 
		ret_str = ret_str.."\tCOM32 "..entry["com32"].."\n"
	end
	if entry["kernel"] ~= nil then 
		ret_str = ret_str.."\tKERNEL "..entry["kernel"].."\n"
	end
	if entry["append"] ~= nil or entry["initrd"] ~= nil then 
		ret_str = ret_str.."\tAPPEND "
		if entry["append"] ~= nil then
			ret_str = ret_str..entry["append"].." " end
		if entry["initrd"] ~= nil then
			ret_str = ret_str.."initrd="..entry["initrd"].." " end
	end
	for i = 0,100 do 
		local pxe_key = "pxe"..i
		if entry[pxe_key] ~= nil then
			ret_str = ret_str..entry[pxe_key].."\n" end
	end
	ret_str = ret_str.."\n"
	return ret_str
end

function create_pxe_node_file(node,handle,config) 
	if config.clustduct["overwrite"] == nil then config.clustduct["overwrite"] = false end
	local file, err = io.open(config.clustduct["confdir"].."/pxe_iptemplate","r")
	if not file then error(err) end
	local pxe_template = file:read("*a")
	file:close()
	-- now create boot entry table
	local sentr = ""
	local entry_name = {}
	local node_args = handle:getattr(node)
	pxe_template = string.gsub(pxe_template,"$NODE",node)	
	if node_args["ip"] ~= nil then 
		pxe_template = string.gsub(pxe_template,"$IP",node_args["ip"]) end
	if node_args["mac"] ~= nil then 
		pxe_template = string.gsub(pxe_template,"$MAC",node_args["mac"]) 
	else
		pxe_template = string.gsub(pxe_template,"$MAC","No mac specified") 
	end
	if node_args["boot"] ~= nil then
		local boot_args = handle:getattr(node_args["boot"])
		if boot_args ~= nil then
			sentr = sentr..create_entry_pxe(boot_args,node_args["boot"]) 
			entry_name[node_args["boot"]] = true
	end end
	if node_args["install"] ~= nil then
		local boot_args = handle:getattr(node_args["install"])
		if boot_args ~= nil then
			sentr = sentr..create_entry_pxe(boot_args,node_args["install"]) 
			entry_name[node_args["install"]] = true
	end end
	local mand_entries = handle:query("mandatory")
	if mand_entries ~= nil then  
		for key,value in pairs(mand_entries) do
			if entry_name[value] == nil then 
				local boot_args = handle:getattr(value)
				sentr = sentr..create_entry_pxe(boot_args,value)
				entry_name[value] = true
			end
		end
	end
	sentr = clean_genders_str(sentr)
	pxe_template = string.gsub(pxe_template,"$ENTRY",sentr)	

	local ofile_name = config.clustduct['tftpdir']..'/'..config.clustduct["outdir"].."/"
	ofile_name = string.gsub(ofile_name,"//","/")
	ofile_name = ofile_name.."clustduct_node."..node..".pxe"
	if not file_exists(ofile_name) or config.clustduct["overwrite"] then
		local ofile, err = io.open(ofile_name,"w")
		if err ~= nil then
			error(err)
		end
		ofile:write(pxe_template)
		ofile:close()
	end
	if node_args["mac"] ~= nil then 
		local mac_filename = config.clustduct["tftpdir"].."/"
		mac_filename = mac_filename.."pxelinux.cfg/"..config.clustduct["netclass"].."-"..node_args["mac"]
		mac_filename = string.gsub(mac_filename,":","-")
		mac_filename = string.gsub(mac_filename,"//","/")
		if not file_exists(mac_filename) or config.clustduct["overwrite"] then
			local mac_file_out = "# Hardware specific node file automatically generated by clustduct\nDEFAULT menu.c32\nAPPEND "..ofile_name
			local ofile, err = io.open(mac_filename,"w")
			if err ~= nil then
				error(err)
			end
			ofile:write(mac_file_out)
			ofile:close()
		end
	end
end
function create_entry_grub(entry,name)
	ret_str = ""
	ret_str = ret_str.."menuentry"
	name = name or "Boot_to_the_unknown"
	if entry["menu"] ~= nil then 
		ret_str = ret_str.." '"..entry["menu"].."' {\n\tset gfxpayload=keep\n"
	else
		ret_str = ret_str.." '"..name.."' {\n\tset gfxpayload=keep\n"
	end
	if entry["kernel"] ~= nil then 
		ret_str = ret_str.."\techo 'Loading kernel ...'\n\tlinuxefi "..entry["kernel"] end
	if entry["linuxefi"] ~= nil then 
		ret_str = ret_str.."\techo 'Loading kernel ...'\n\tlinuxefi "..entry["linuxefi"] end
	if entry["append"] ~= nil and 
		(entry["kernel"] ~= nil or entry["linuxefi"] ~= nil ) then
		ret_str = ret_str.." "..entry["append"].."\n" end
	if entry["initrd"] ~= nil then
		ret_str = ret_str.."\techo 'Loading initial ramdisk ...'\n\tinitrdefi "..entry["initrd"].."\n" end
	if entry["initrdefi"] ~= nil then
		ret_str = ret_str.."\tinitrdefi "..entry["initrdefi"].."\n" end
	if entry["set"] ~= nil then
		ret_str = ret_str.."\tset "..entry["set"].."\n" end
	if entry["chainloader"] ~= nil then
		ret_str = ret_str.."\tchainloader"..entry["chainloader"].."\n" end
	if entry["grub"] ~= nil then
		ret_str = ret_str.."\t"..entry["grub"].."\n" end
	for i = 0,100 do 
		local grub_key = "grub"..i
		if entry[grub_key] ~= nil then
			ret_str = ret_str..entry[grub_key].."\n" end
	end
	ret_str = ret_str.."\n}\n"
	return ret_str
end

function create_grub_node_file(node,handle,config) 
	if config.clustduct["overwrite"] == nil then config.clustduct["overwrite"] = false end
	local file, err = io.open(config.clustduct["confdir"].."/grub_iptemplate","r")
	if not file then error(err) end
	local grub_template = file:read("*a")
	file:close()
	-- now create boot entry table
	local sentr = ""
	local entry_name = {} 
	local node_args = handle:getattr(node)
	grub_template = string.gsub(grub_template,"$NODE",node)	
	if node_args["ip"] ~= nil then 
		grub_template = string.gsub(grub_template,"$IP",node_args["ip"]) end
	if node_args["mac"] ~= nil then 
		grub_template = string.gsub(grub_template,"$MAC",node_args["mac"]) 
	else
		grub_template = string.gsub(grub_template,"$MAC","No mac specified") 
	end
	if node_args["boot"] ~= nil then
		local boot_args = handle:getattr(node_args["boot"])
		if boot_args ~= nil then
			sentr = sentr..create_entry_grub(boot_args,node_args)
			entry_name[node_args["boot"]] = true
	end end
	if node_args["install"] ~= nil then
		local boot_args = handle:getattr(node_args["install"])
		if boot_args ~= nil then
			sentr = sentr..create_entry_grub(boot_args,node_args["install"])
			entry_name[node_args["install"]] = true
	end end
	local mand_entries = handle:query("mandatory")
	if mand_entries ~= nil then  
		for key,value in pairs(mand_entries) do
			if entry_name[value] == nil then 
				local boot_args = handle:getattr(value)
				sentr = sentr..create_entry_grub(boot_args,value)
				entry_name[value] = true
			end
		end
	end
	sentr = clean_genders_str(sentr)
	grub_template = string.gsub(grub_template,"$ENTRY",sentr)	

	local ofile_name = config.clustduct['tftpdir']..'/'..config.clustduct["outdir"].."/"
	ofile_name = string.gsub(ofile_name,"//","/")
	ofile_name = ofile_name.."clustduct_node."..node..".grub"
	if not file_exists(ofile_name) or config.clustduct["overwrite"] then
		local ofile, err = io.open(ofile_name,"w")
		if err ~= nil then
			error(err)
		end
		ofile:write(grub_template)
		ofile:close()
	end
	local ip_filename = config.clustduct['tftpdir']..'/'..config.clustduct["outdir"].."/"
	ip_filename = string.gsub(ip_filename,"//","/")
	ip_filename = ip_filename.."grub.cfg."..node_args["ip"]
	if not file_exists(ip_filename) or config.clustduct["overwrite"] then
		local ip_file_out = "# IP specific configfile automatically generated by clustduct\nconfigfile "..config.clustduct["outdir"].."/".."clustduct_node."..node..".grub"
		ip_file_out = string.gsub(ip_file_out,"//","/")
		local ofile, err = io.open(ip_filename,"w")
		if err ~= nil then
			error(err)
		end
		ofile:write(ip_file_out)
		ofile:close()
	end
	if node_args["mac"] ~= nil then 
		local mac_filename = config.clustduct["tftpdir"].."/"
		mac_filename = mac_filename.."pxelinux.cfg/clustduct_"..node_args["mac"]..".grub"
		mac_filename = string.gsub(mac_filename,"//","/")
		if not file_exists(mac_filename) or config.clustduct["overwrite"] then
			local mac_file_out = "# Hardware specific node file automatically generated by clustduct\nset timeout=1\nmenuentry 'Call node specific file' {\n\tconfigfile "..ofile_name.."\n}"
			local ofile, err = io.open(mac_filename,"w")
			if err ~= nil then
				error(err)
			end
			ofile:write(mac_file_out)
			ofile:close()
		end
	end

end

function create_pxe_structure(handle,config)
	if config.clustduct["overwrite"] == nil then config.clustduct["overwrite"] = false end
	if config.clustduct["base"] == nil then config.clustduct["base"] = 10 end
	local incrementcount=0
	local nodes = handle:query("ip")
	-- nr_nodes=$(nodeattr -f $GENDERSFILE -n ip | wc -l)
	-- base=${BASE:-10}
	local exponent = math.floor(math.log(#nodes)/math.log(config.clustduct["base"]))
	local counter=1
	local level=0
	local i=1
	local output_str = "# Syslinux boot structure automatically generated by clustduct\n"
	-- clean up preexisting entries
	local ofile_name = config.clustduct['tftpdir']..'/'..config.clustduct["outdir"].."/"
	ofile_name = string.gsub(ofile_name,"//","/")
	ofile_name = ofile_name.."menu.pxe"
	if not config.clustduct["overwrite"] then
		if file_exists(ofile_name) then return end
	end
	for key, node in pairs(nodes)  do
		if counter == 1  then
			for n = 1, exponent  do
				local modulo = (i-1)%(config.clustduct["base"]^n)
				if modulo == 0  then
					output_str = output_str.."MENU BEGIN list_"..node.."\nMENU LABEL Boot "..node.." to ENDNODE\n"
					level = level+1
				end
			end
		end	
		-- to pxe menu structure
		output_str = output_str.."LABEL "..node.."\n\tMENU LABEL Boot as node "..node.."\n\tKERNEL menu.c32\n\tAPPEND "..config.clustduct["outdir"].."/clustduct_node."..node..".pxe\n"
		-- to the node file
		create_pxe_node_file(node,handle,config) 
		if counter == config.clustduct["base"]  then
			for n = 1, exponent do
				local modulo = i%(config.clustduct["base"]^n)
				if modulo == 0 then
					output_str = output_str.."LABEL go_back\n\tMENU LABEL Go back...\n\tMENU EXIT\nMENU END"
					output_str = string.gsub(output_str,"ENDNODE",node)

					level = level - 1
				end
			end
		end
		if counter < config.clustduct["base"]  then
			counter = counter + 1
		else
			counter = 1
		end
		i = i + 1
	end
	for n = 1, level do
		output_str = output_str.."LABEL go_back\n\tMENU LABEL Go back...\n\tMENU EXIT\n\tMENU END\n"
	end
	output_str = output_str.."LABEL go_back\n\tMENU LABEL Go back...\n\tKERNEL menu.c32\n\tAPPEND ~\n"
	if not file_exists(ofile_name) or config.clustduct["overwrite"] then
		local ofile, err = io.open(ofile_name,"w")
		if err ~= nil then
			error(err)
		end
		ofile:write(output_str)
		ofile:close()
	end

end

function create_grub_structure(handle,config)
	if config.clustduct["overwrite"] == nil then config.clustduct["overwrite"] = false end
	if config.clustduct["base"] == nil then config.clustduct["base"] = 10 end
	local incrementcount=0
	local nodes = handle:query("ip")
	-- nr_nodes=$(nodeattr -f $GENDERSFILE -n ip | wc -l)
	-- base=${BASE:-10}
	local exponent = math.floor(math.log(#nodes)/math.log(config.clustduct["base"]))
	local counter = 1
	local i=1
	local output_str = "# Grub boot structure automatically generated by clustduct\n"
	local menu_str = ""
	-- clean up preexisting entries
	local ofile_name_base = config.clustduct['tftpdir']..'/'..config.clustduct["outdir"].."/"
	ofile_name_base = string.gsub(ofile_name_base,"//","/")
	local ofile_name = ""
	for key, node in pairs(nodes)  do
		if counter == 1  then
			output_str = "set timeout=10\n"
			for n = 1, exponent  do
				local modulo = (i-1)%(config.clustduct["base"]^n)
				if modulo == 0  then
					-- output_str = "set timeout=10\nmenuentry 'Boot from node "..node.." to ENDNODE {\n"
					ofile_name = ofile_name_base.."node_"..i
					menu_str = menu_str.."menuentry 'Boot from "..node
				end
			end
		end	
		-- to grub menu structure
		output_str = output_str.."menuentry 'Boot as "..node.."' {\n\tconfigfile "..config.clustduct["outdir"].."/clustduct_node."..node..".grub\n}\n"
		-- to the node file
		create_grub_node_file(node,handle,config) 
		if counter < config.clustduct["base"] and i ~= #nodes then
			counter = counter + 1
		else
			output_str = output_str.."menuentry 'Go back...' {\n\tconfigfile "..config.clustduct["outdir"].."/grub-main.cfg\n}\n"
			ofile_name = ofile_name.."_to_node_"..i..".grub"
			menu_str = menu_str.." to "..node.."' {\n\t".."configfile "..ofile_name.."\n}\n"
			-- dirty trick to remove leading configdir
			menu_str = string.gsub(menu_str,config.clustduct['tftpdir'],'')
			if not file_exists(ofile_name) or config.clustduct["overwrite"] then
				local ofile, err = io.open(ofile_name,"w")
				if err ~= nil then
					error(err)
				end
				ofile:write(output_str)
				ofile:close()
			end
			counter = 1
		end
		i = i + 1
	end
	local menu_file_str = config.clustduct['tftpdir']..'/'..config.clustduct["outdir"].."/"
	menu_file_str = string.gsub(menu_file_str,"//","/")
	menu_file_str = menu_file_str.."menu.grub"
	if not file_exists(menu_file_str) or config.clustduct["overwrite"] then
		local ofile, err = io.open(menu_file_str,"w")
		if err ~= nil then
			error(err)
		end
		ofile:write(menu_str)
		ofile:close()
	end
	-- output_str = output_str.."LABEL go_back\n\tMENU LABEL Go back...\n\tKERNEL menu.c32\n\tAPPEND ~\n"


end

function clean_genders(table)
	for key,value in pairs(table) do 
		local t_str = value
		t_str = string.gsub(t_str,"\\ws"," ")
		t_str = string.gsub(t_str,"\\eq","=")
		t_str = string.gsub(t_str,"\\co",",")
		table[key] = t_str
	end
end

function clean_genders_str(str)
	str = string.gsub(str,"\\ws"," ")
	str = string.gsub(str,"\\eq","=")
	str = string.gsub(str,"\\co",",")
	return str
end

function create_entry(entry,entries,handle)
	-- avoid double entries
	if entries[entry] ~= nil then return end
	local boot_args = handle:getattr(entry)
	if boot_args ~= nil then 
		-- do the pattern substiutions like \eq -> = here
		clean_genders(boot_args)
		entries[entry] = boot_args
	end

end

function file_exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end
