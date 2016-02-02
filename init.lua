--
-- Mod GPS
--

-- Destinations set limit that a player can have on GPS
-- Definir limite de Destinos que um jogador pode ter no gps
local LIMITE = 3

-- Time (in seconds) between each check inventory to see if this with a GPS
-- Tempo (em segundos) entre cada verificacao de inventario para saber se esta com um gps
local TEMPO = 5

-- Tradutor de String
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	S = function(s,a,...)if a==nil then return s end a={a,...}return s:gsub("(@?)@(%(?)(%d+)(%)?)",function(e,o,n,c)if e==""then return a[tonumber(n)]..(o==""and c or"")else return"@"..o..n..c end end) end
end

--
-----
--------
-- Banco de dados
local path = minetest.get_worldpath()
local pathbd = path .. "/gps"

-- Cria o diretorio caso nao exista ainda
local function mkdir(pathbd)
	if minetest.mkdir then
		minetest.mkdir(pathbd)
	else
		os.execute('mkdir "' .. pathbd .. '"')
	end
end
mkdir(pathbd)

local registros = {}

-- Carregar na memoria dados de um jogador
local carregar_dados = function(name)
	local input = io.open(pathbd .. "/gps_"..name, "r")
	if input then
		registros[name] = minetest.deserialize(input:read("*l"))
		io.close(input)
		return true
	else
		return false
	end
end

-- Salvar registros de trabalhos
local salvar_dados = function(name)
	local output = io.open(pathbd .. "/gps_"..name, "w")
	output:write(minetest.serialize(registros[name]))
	io.close(output)
end

-- Tirar dados de jogadores que sairem do servidor
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	registros[name] = nil
end)

-- Registra apenas novos jogadores
minetest.register_on_newplayer(function(player)
	local name = player:get_player_name()
	registros[name] = {
		string = "",
		destinos = {}
	}
	salvar_dados(name)
	carregar_dados(player:get_player_name())
end)

-- Carrega dados de jogadores que conectam
minetest.register_on_joinplayer(function(player)
	if carregar_dados(player:get_player_name()) == false then
		local name = player:get_player_name()
		registros[name] = {
			string = "",
			destinos = {}
		}
		salvar_dados(name)
		carregar_dados(name)
	end
end)
-- Fim
--------
-----
--

--
-----
--------
-- Craftitem
minetest.register_craftitem("gps:gps", { -- GPS
	description = S("GPS"),
	stack_max = 1,
	inventory_image = "gps_item.png",
	on_use = function(itemstack, user, pointed_thing)
		local name = user:get_player_name()
		local formspec = "size[5,4]"
			.."bgcolor[#08080800]"
			.."background[0,0;5,4;gps_bg.png;true]"
			.."label[0.1,-0.1;"..S("Destinos").."]"
			.."dropdown[0.1,0.4;5,1;destino;"..registros[name].string..";1]"
			.."button_exit[0.1,1.1;1.7,1;ir;"..S("Localizar").."]"
			.."button_exit[1.7,1.1;1.7,1;desligar;"..S("Desligar").."]"
			.."button_exit[3.3,1.1;1.6,1;deletar;"..S("Deletar").."]"
			.."field[0.3,2.9;5,1;nome_destino;"..S("Novo Destino")..";"..S("Nome Desse Lugar").."]"
			.."button_exit[0,3.3;5,1;gravar;"..S("Gravar Novo Destino").."]"
		minetest.show_formspec(name, "gps:gps", formspec)
	end,
})
minetest.register_craft({ -- Receita de GPS
	output = "gps:gps",
	recipe = {
		{"default:steel_ingot", "dye:orange", "default:steel_ingot"},
		{"default:steel_ingot", "default:diamond", "default:steel_ingot"},
		{"default:stick", "default:stick", "default:stick"}
	}
})
-- Fim
--------
-----
--

-- Atualizar string
local atualizar_string = function(name)
	registros[name].string = ""
	local i = 0
	for destino, pos in pairs(registros[name].destinos) do
		if i > 0 then registros[name].string = registros[name].string .. "," end
		registros[name].string = registros[name].string .. destino
		i = i + 1
	end
end

-- Variavel global de waypoints
local waypoints = {}

-- Verificar Waypoint
local temporizador = 0
minetest.register_globalstep(function(dtime)
	temporizador = temporizador + dtime
	if temporizador >= TEMPO then
		local waypoints_validos = {}
		for name, waypoint in pairs(waypoints) do
			local player = minetest.get_player_by_name(name)
			if not player or not player:get_inventory():contains_item(player:get_wield_list(), "gps:gps") then
				if player then 
					player:hud_remove(waypoints[name]) 
					minetest.chat_send_player(name, S("Precisa estar com o GPS para ir ao destino."))
				end
			else
				waypoints_validos[name] = waypoints[name]
			end
		end
		waypoints = waypoints_validos
		temporizador = 0
	end
end)

-- Adicionar Waypoint
local adicionar_waypoint = function(name, destino)
	local player = minetest.get_player_by_name(name)
	if waypoints[name] then 
		player:hud_remove(waypoints[name])
	end
	waypoints[name] = player:hud_add({
		hud_elem_type = "waypoint",
		name = destino,
		number = "16747520",
		world_pos = registros[name].destinos[destino]
	})
end

-- Recebedor de campos
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "gps:gps" then
		local name = player:get_player_name()
		if fields.ir then
			if registros[name].destinos[fields.destino] then
				adicionar_waypoint(name, fields.destino)
				minetest.chat_send_player(name, S("GPS Ativado. Destino @1 localizado.", fields.destino))
				minetest.sound_play("gps_beep", {gain = 0.15, max_hear_distance = 3, object = player})
				return true
			else
				minetest.chat_send_player(name, S("Nenhum destino encontrado. Defina novos destinos."))
				return true
			end
		elseif fields.desligar then
			if waypoints[name] then
				player:hud_remove(waypoints[name])
			end
			minetest.chat_send_player(name, S("GPS desligado."))
			return true
		elseif fields.gravar then
			if fields.nome_destino then
				if not fields.nome_destino:find("{") 
					and not fields.nome_destino:find("}") 
					and not fields.nome_destino:find(",") 
					and not fields.nome_destino:find("\\") 
					and not fields.nome_destino:find("\"")
				then
					if fields.nome_destino == "" then
						minetest.chat_send_player(name, S("Nenhum nome definido para o lugar. Digite um nome."))
						return true
					end
					-- verificar quantos ja tem
					local total = 0
					for destino, pos in pairs(registros[name].destinos) do
						total = total + 1
					end
					if total >= LIMITE then
						minetest.chat_send_player(name, S("Limite de @1 destinos no seu GPS. Delete algum dos ja existentes.", LIMITE))
						return true
					end
					registros[name].destinos[fields.nome_destino] = player:getpos()
					atualizar_string(name)
					salvar_dados(name)
					minetest.chat_send_player(name, S("Lugar @1 foi gravado no seu GPS.", fields.nome_destino))
					-- Caso ja tenha e esteja ativo entao ajusta o waypoint visualizado
					if tonumber(waypoints[name]) and player:hud_get(waypoints[name]) then
						local def = player:hud_get(waypoints[name])
						if def.name == fields.nome_destino then adicionar_waypoint(name, fields.nome_destino) end
					end
					return true
				else
					minetest.chat_send_player(name, S("Caracteres invalidos. Tente utilizar apenas letras e numeros no novo nome."))
					return true
				end
			else
				minetest.chat_send_player(name, S("Nenhum nome especificado para o novo lugar. Defina o nome desse lugar."))
				return true
			end
		elseif fields.deletar then
			if fields.destino and fields.destino ~= "" then
				if tonumber(waypoints[name]) then
					player:hud_remove(waypoints[name])
				end
				local destinos_restantes = {} -- realoca destinos na memoria
				for destino, pos in pairs(registros[name].destinos) do
					if destino ~= fields.destino then
						destinos_restantes[destino] = pos
					end
				end
				registros[name].destinos = destinos_restantes
				atualizar_string(name)
				salvar_dados(name)
				minetest.chat_send_player(name, S("Destino @1 deletado.", fields.destino))
				return true
			else
				minetest.chat_send_player(name, S("Nenhum destino para deletar."))
				return true
			end
		end
	end
end)

-- Tira waypoint quando o jogador morre
minetest.register_on_dieplayer(function(player)
	if waypoints[player:get_player_name()] then
		player:hud_remove(waypoints[name])
	end
end)
