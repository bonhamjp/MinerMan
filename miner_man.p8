pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- constants
playing_game = false

wall_tile = 47
rock_tile = 32
exit_tile = 46
background_tiles = {16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31}

full_heart_sprite = 63
empty_heart_sprite = 62
increase_bombs_sprite = 61
increase_explosion_sprite = 60
increase_speed_sprite = 59
decrease_cooldown_sprite = 58

minimum_dungeon_sections = 1
base_dungeon_sections = 1
base_animation_duration = 0.25

bomb_countdown_time = 1
explosion_countdown_time = 0.2
explosion_duration = 0.4

player_health = 3
player_speed = 30
player_cooldown_duration = 2.5
player_explosion_spread = 1
player_bomb_drop_count = 1

max_player_speed = 60
player_speed_increase = 1.5
min_player_cooldown_duration = 0.5
player_cooldown_duration_decrease = 0.1
max_player_explosion_spread = 14
player_explosion_spread_increase = 1
max_player_bomb_drop_count = 6
player_bomb_drop_count_increase = 1

invincible_duration = 1

blob_1_health = 1
blob_1_speed = 15
blob_1_points = 50
blob_1_bump_timeout = 0.1

blob_2_health = 1
blob_2_speed = 20
blob_2_points = 100
blob_2_bump_timeout = 0.1

-- globals
previous_time = time()
current_time = time()
delta_time = 0

current_score = 0
current_floor = 1

top_score = 0
top_floor = 0

-- game objects
player = {}  -- player state
dungeon = {} -- procedural map state

-- cache objects/settings from current section
can_move_to_section_up = false
can_move_to_section_down = false
can_move_to_section_left = false
can_move_to_section_right = false

current_section_y = 0
current_section_x = 0

current_floor_tiles = {}
current_rocks = {}
current_walls = {}
current_items = {}
current_bombs = {}
current_enemies = {}

-- GAME SETUP
-------------

function setup_player()
	player = {
		is_enemy = false,
		flipped = false,
		health = player_health,
		speed = player_speed,
		cooldown_duration = player_cooldown_duration,
		cooldown_timer = 0,
		invincible_duration = invincible_duration,
		invincible_timer = 0,
		explosion_spread = player_explosion_spread,
		bomb_drop_count = player_bomb_drop_count,
		bombs_dropped = 0,
		drop_duration = 0.25,
		drop_timer = 0,
		position = {12, 12},
		hit_adjustments = {2, 3, 4, 3},
		frames = {1, 2},
		animation_time = 0,
		is_animated = false,
		collides_with_bombs = false
	}

	function player:update()
		self.cooldown_timer -= delta_time
		self.drop_timer -= delta_time

		if self.cooldown_timer <= 0 then
			self.bombs_dropped = 0
		end

		self.invincible_timer -= delta_time

		if self.invincible_timer <= 0 then
			self.frames = {1, 2}
		else
			self.frames = {14, 15}
		end

		-- move player
		if (btn(0)) then
			self.flipped = true
			move_sprite(player, player.position[1] - (player.speed * delta_time), player.position[2])
			continue_animation(player)
		elseif (btn(1)) then
			self.flipped = false
			move_sprite(player, player.position[1] + (player.speed * delta_time), player.position[2])
			continue_animation(player)
		elseif (btn(2)) then
			move_sprite(player, player.position[1], player.position[2] - (player.speed * delta_time))
			continue_animation(player)
		elseif (btn(3)) then
			move_sprite(player, player.position[1], player.position[2] + (player.speed * delta_time))
			continue_animation(player) 
		else
			stop_animation(player)
		end

		-- drop bomb
		if (btn(4)) and (self.cooldown_timer < 0 or (self.drop_timer < 0 and self.bombs_dropped < self.bomb_drop_count)) then
			if self.cooldown_timer <= 0 then
				self.cooldown_timer = self.cooldown_duration
			end

			self.drop_timer = self.drop_duration
			self.bombs_dropped += 1
			add(current_bombs, create_bomb(center_sprite_coord(self.position[1]), center_sprite_coord(self.position[2])))
		end

		-- move sectors if past screen boundry
		if self.position[2] < 4 then 
			store_dungeon_section()
			self.position[2] = 124
			load_dungeon_section(current_section_y - 1, current_section_x)
		end

		if self.position[2] > 124 then
			store_dungeon_section()
			self.position[2] = 4
			load_dungeon_section(current_section_y + 1, current_section_x)
		end
		
		if self.position[1] < 4 then
			store_dungeon_section()
			self.position[1] = 124
			load_dungeon_section(current_section_y, current_section_x - 1)
		end

		if self.position[1] > 124 then
			store_dungeon_section()
			self.position[1] = 4
			load_dungeon_section(current_section_y, current_section_x + 1)
		end

		-- check if exit reached
		if current_section_x == dungeon.exit[1] and current_section_y == dungeon.exit[2] then
			hit_box_x_1 = self.position[1] + self.hit_adjustments[1]
			hit_box_x_2 = hit_box_x_1 + self.hit_adjustments[2]
			hit_box_y_1 = self.position[2] + self.hit_adjustments[3]
			hit_box_y_2 = hit_box_y_1 + self.hit_adjustments[4]

			if (hit_box_x_1 < dungeon.exit[3] + 8) and (hit_box_x_2 > dungeon.exit[3]) and (hit_box_y_1 < dungeon.exit[4] + 8) and (hit_box_y_2 > dungeon.exit[4]) then
				current_score += 100
				current_floor += 1

				generate_dungeon()
			end
		end
	end

	function player:draw()
		draw_sprite(self)
	end

	function player:damage()
		if self.invincible_timer <= 0 then
			sfx(3)

			self.invincible_timer = self.invincible_duration
			self.health -= 1
			if self.health <= 0 then
				reset_game()
			end
		end
	end

	function player:heal()
		if self.health < 3 then
			self.health += 1
		end
	end

	function player:increase_speed()
		if self.speed < max_player_speed then
			self.speed += player_speed_increase
		end
	end

	function player:decrease_cooldown_duration()
		if self.cooldown_duration > min_player_cooldown_duration then
			self.cooldown_duration -= player_cooldown_duration_decrease
		end
	end

	function player:increase_explosion_spread()
		if self.explosion_spread < max_player_explosion_spread then
			self.explosion_spread += player_explosion_spread_increase
		end
	end

	function player:increase_bomb_drop_amount()
		if self.bomb_drop_count < max_player_bomb_drop_count then
			self.bomb_drop_count += player_bomb_drop_count_increase
		end
	end
end

function generate_dungeon()
	sections_x = flr(rnd(current_floor * 0.5) + flr(rnd(base_dungeon_sections)) + minimum_dungeon_sections)
	sections_y = flr(rnd(current_floor * 0.5) + flr(rnd(base_dungeon_sections)) + minimum_dungeon_sections)

	floor_tiles = {}
	rocks = {}
	walls = {}
	items = {}
	bombs = {}
	enemies = {}
	for i = 0, (sections_y - 1) do 
  	for j = 0, (sections_x - 1) do
			section_floor_tiles = {}
			section_rocks = {}
			section_walls = {}
			section_items = {}
			section_bombs = {}
			section_enemies = {}
			for row = 0, 15 do
				for column = 0, 15 do
					section_floor_tiles[(row * 16) + column] = background_tiles[flr(rnd(count(background_tiles))) + 1]
						
					sprite_offset_x = (column * 8) + 4
					sprite_offset_y = (row * 8) + 4

					if (i == 0 and row == 0) or (i == (sections_y - 1) and row == 15) or (j == 0 and column == 0) or (j == (sections_x - 1) and column == 15) then
						add(section_walls, create_wall(sprite_offset_x, sprite_offset_y))
					else
						only_rocks = row == 0 or row == 15 or column == 0 or column == 15 	
						if flr(rnd(2)) == 0 then
							add(section_rocks, create_rock(sprite_offset_x, sprite_offset_y))
						elseif (flr(rnd(30 / current_floor)) == 0) then
							add(section_rocks, create_tough_rock(sprite_offset_x, sprite_offset_y))
						elseif only_rocks == false then
							if current_floor <= 4 then
								if (flr(rnd(32)) == 0) then
									add(section_enemies, create_blob_1(sprite_offset_x, sprite_offset_y))
								end
							else
								if (flr(rnd(32)) == 0) then
									add(section_enemies, create_blob_1(sprite_offset_x, sprite_offset_y))
								elseif (flr(rnd(32)) == 0) then
									add(section_enemies, create_blob_2(sprite_offset_x, sprite_offset_y))
								end
							end
						end
					end
				end
			end
			section_index = (i * sections_x) + j 
			floor_tiles[section_index] = section_floor_tiles
			walls[section_index] = section_walls
			rocks[section_index] = section_rocks
			items[section_index] = section_items
			bombs[section_index] = section_bombs
			enemies[section_index] = section_enemies
		end 
	end

	-- randomly choose location of exit
	exit_section_x = flr(rnd(sections_x))
	exit_section_y = flr(rnd(sections_y))
	exit_x = flr(12 + (8 * flr(rnd(12))))
	exit_y = flr(12 + (8 * flr(rnd(12))))

	-- place rock over exit, and remove any enemies/items
	section_index = (exit_section_y * sections_x) + exit_section_x
	need_rock = true
	for rock in all(rocks[section_index]) do
		rock_x_1 = rock.position[1] + rock.hit_adjustments[1]
		rock_x_2 = rock_x_1 + rock.hit_adjustments[2]
		rock_y_1 = rock.position[2] + rock.hit_adjustments[3]
		rock_y_2 = rock_y_1 + rock.hit_adjustments[4]
		
		if (exit_x < rock_x_2) and (exit_x + 8 > rock_x_1) and (exit_y < rock_y_2) and (exit_y + 8 > rock_y_1) then
			need_rock = false
		end
	end

	if need_rock then
		add(rocks[section_index], create_rock(exit_x, exit_y))
	end

	-- randomly choose location of player
	player_section_x = flr(rnd(sections_x))
	player_section_y = flr(rnd(sections_y))

	player.position[1] = flr(20 + (8 * flr(rnd(10)))) 
	player.position[2] = flr(20 + (8 * flr(rnd(10))))

	-- remove rocks/enemies adjacent to player
	section_index = (player_section_y * sections_x) + player_section_x
	up_from_player = {player.position[1], player.position[2] - 8}
	down_from_player = {player.position[1], player.position[2] + 8}
	left_from_player = {player.position[1] - 8, player.position[2]}
	right_from_player = {player.position[1] + 8, player.position[2]}

	for rock in all(rocks[section_index]) do
		rock_x_1 = rock.position[1] + rock.hit_adjustments[1]
		rock_x_2 = rock_x_1 + rock.hit_adjustments[2]
		rock_y_1 = rock.position[2] + rock.hit_adjustments[3]
		rock_y_2 = rock_y_1 + rock.hit_adjustments[4]

		if (player.position[1] < rock_x_2) and (player.position[1] + 8 > rock_x_1) and (player.position[2] < rock_y_2) and (player.position[2] + 8 > rock_y_1) then
			rock.should_remove = true
		elseif (up_from_player[1] < rock_x_2) and (up_from_player[1] + 8 > rock_x_1) and (up_from_player[2] < rock_y_2) and (up_from_player[2] + 8 > rock_y_1) then
			rock.should_remove = true
		elseif (down_from_player[1] < rock_x_2) and (down_from_player[1] + 8 > rock_x_1) and (down_from_player[2] < rock_y_2) and (down_from_player[2] + 8 > rock_y_1) then
			rock.should_remove = true
		elseif (left_from_player[1] < rock_x_2) and (left_from_player[1] + 8 > rock_x_1) and (left_from_player[2] < rock_y_2) and (left_from_player[2] + 8 > rock_y_1) then
			rock.should_remove = true
		elseif (right_from_player[1] < rock_x_2) and (right_from_player[1] + 8 > rock_x_1) and (right_from_player[2] < rock_y_2) and (right_from_player[2] + 8 > rock_y_1) then
			rock.should_remove = true
		end
	end

	for enemy in all(enemies[section_index]) do
		enemy_x_1 = enemy.position[1] + enemy.hit_adjustments[1]
		enemy_x_2 = enemy_x_1 + enemy.hit_adjustments[2]
		enemy_y_1 = enemy.position[2] + enemy.hit_adjustments[3]
		enemy_y_2 = enemy_y_1 + enemy.hit_adjustments[4]

		if (player.position[1] < enemy_x_2) and (player.position[1] + 8 > enemy_x_1) and (player.position[2] < enemy_y_2) and (player.position[2] + 8 > enemy_y_1) then
			enemy.should_remove = true
		elseif (up_from_player[1] < enemy_x_2) and (up_from_player[1] + 8 > enemy_x_1) and (up_from_player[2] < enemy_y_2) and (up_from_player[2] + 8 > enemy_y_1) then
			enemy.should_remove = true
		elseif (down_from_player[1] < enemy_x_2) and (down_from_player[1] + 8 > enemy_x_1) and (down_from_player[2] < enemy_y_2) and (down_from_player[2] + 8 > enemy_y_1) then
			enemy.should_remove = true
		elseif (left_from_player[1] < enemy_x_2) and (left_from_player[1] + 8 > enemy_x_1) and (left_from_player[2] < enemy_y_2) and (left_from_player[2] + 8 > enemy_y_1) then
			enemy.should_remove = true
		elseif (right_from_player[1] < enemy_x_2) and (right_from_player[1] + 8 > enemy_x_1) and (right_from_player[2] < enemy_y_2) and (right_from_player[2] + 8 > enemy_y_1) then
			enemy.should_remove = true
		end
	end

	dungeon = {
		sections_x = sections_x,
		sections_y = sections_y,
		floor_tiles = floor_tiles,
		rocks = rocks,
		walls = walls,
		items = items,
		bombs = bombs,
		enemies = enemies,
		exit = { exit_section_x, exit_section_y, exit_x, exit_y },
		exit_not_shown = true
	}

	-- load section of dungeon player starts in
	load_dungeon_section(player_section_y, player_section_x)
end

function create_wall(x, y)
	wall = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {wall_tile},
		animation_time = 0,
	}

	function wall:draw()
		draw_sprite(self)
	end

	return wall
end

function create_rock(x, y)
	rock = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {rock_tile},
		should_remove = false,
	}

	function rock:update()
	end

	function rock:draw()
		spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
	end

	function rock:damage()
		self.should_remove = true
	end

	return rock
end

function create_tough_rock(x, y)
	tough_rock = {
		resilience = 2,
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {33, 34},
		invincible_duration = invincible_duration,
		invincible_timer = 0,
		should_remove = false
	}

	function tough_rock:update()
		self.invincible_timer -= delta_time
	end

	function tough_rock:draw()
		if self.resilience == 2 then
			spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
		else
			spr(self.frames[2], self.position[1] - 4, self.position[2] - 4)
		end
	end

	function tough_rock:damage()
		if self.invincible_timer <= 0 then
			self.invincible_timer = self.invincible_duration
			self.resilience -= 1
			if self.resilience <= 0 then
				self.should_remove = true
			end
		end
	end

	return tough_rock
end

function create_blob_1(x, y)
	move_direction = flr(rnd(4))
	if move_direction == 0 then
		direction = {-1, 0}
	elseif move_direction == 1 then
		direction = {1, 0}
	elseif move_direction == 2 then
		direction = {0, 1}
	else
		direction = {0, -1}
	end

	blob_1 = {
		is_enemy = true,
		flipped = false,
		health = blob_1_health,
		speed = blob_1_speed,
		points = blob_1_points,
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {48, 49},
		direction = direction,
		animation_time = 0,
		is_animated = true,
		should_remove = false,
		collides_with_bombs = true,
		bump_timeout = blob_1_bump_timeout,
		bump_timer = 0
	}

	function blob_1:update()
		continue_animation(self)

		self.bump_timer -= delta_time
		if self.bump_timer <= 0 then
			if see_sprite_up(self, player) and ceil(self.position[1]) % 4 == 0 then
				self.direction = {0, -1}
			elseif see_sprite_down(self, player) and ceil(self.position[1]) % 4 == 0 then
				self.direction = {0, 1}
			elseif see_sprite_left(self, player) and ceil(self.position[2]) % 4 == 0 then
				self.flipped = true
				self.direction = {-1, 0}
			elseif see_sprite_right(self, player) and ceil(self.position[2]) % 4 == 0 then
				self.flipped = false
				self.direction = {1, 0}
			end

			if move_sprite(self, self.position[1] + (self.speed * delta_time * self.direction[1]), self.position[2] + (self.speed * delta_time * self.direction[2])) == false then
				self.bump_timer = self.bump_timeout
				
				move_direction = flr(rnd(4))
				if move_direction == 0 then
					self.flipped = true
					self.direction = {-1, 0}
				elseif move_direction == 1 then
					self.flipped = false
					self.direction = {1, 0}
				elseif move_direction == 2 then
					self.direction = {0, 1}
				else
					self.direction = {0, -1}
				end

				self.position[1] = center_sprite_coord(self.position[1])
				self.position[2] = center_sprite_coord(self.position[2])
			end

			-- damage player
			if sprites_collide(self, player) then
				player:damage()
			end
		end
	end

	function blob_1:draw()
		draw_sprite(self)
	end

	function blob_1:damage()
		self.should_remove = true
	end

	return blob_1
end

function create_blob_2(x, y)
	move_direction = flr(rnd(4))
	if move_direction == 0 then
		direction = {-1, 0}
	elseif move_direction == 1 then
		direction = {1, 0}
	elseif move_direction == 2 then
		direction = {0, 1}
	else
		direction = {0, -1}
	end

	blob_2 = {
		is_enemy = true,
		flipped = false,
		health = blob_2_health,
		speed = blob_2_speed,
		points = blob_2_points,
		position = {x, y},
		hit_adjustments = {2, 3, 4, 3},
		frames = {35, 36},
		direction = direction,
		animation_time = 0,
		is_animated = true,
		should_remove = false,
		collides_with_bombs = true,		
		bump_timeout = blob_2_bump_timeout,
		bump_timer = 0
	}

	function blob_2:update()
		continue_animation(self)

		self.bump_timer -= delta_time
		if self.bump_timer <= 0 then
			if see_sprite_up(self, player) and ceil(self.position[1]) % 4 == 0 then
				self.direction = {0, -1}
			elseif see_sprite_down(self, player) and ceil(self.position[1]) % 4 == 0 then
				self.direction = {0, 1}
			elseif see_sprite_left(self, player) and ceil(self.position[2]) % 4 == 0 then
				self.flipped = true
				self.direction = {-1, 0}
			elseif see_sprite_right(self, player) and ceil(self.position[2]) % 4 == 0 then
				self.flipped = false
				self.direction = {1, 0}
			end

			if move_sprite(self, self.position[1] + (self.speed * delta_time * self.direction[1]), self.position[2] + (self.speed * delta_time * self.direction[2])) == false then
				self.bump_timer = self.bump_timeout
				
				move_direction = flr(rnd(4))
				if move_direction == 0 then
					self.flipped = true
					self.direction = {-1, 0}
				elseif move_direction == 1 then
					self.flipped = false
					self.direction = {1, 0}
				elseif move_direction == 2 then
					self.direction = {0, 1}
				else
					self.direction = {0, -1}
				end

				self.position[1] = center_sprite_coord(self.position[1])
				self.position[2] = center_sprite_coord(self.position[2])
			end

			-- damage player
			if sprites_collide(self, player) then
				player:damage()
			end
		end
	end

	function blob_2:draw()
		draw_sprite(self)
	end

	function blob_2:damage()
		self.should_remove = true
	end

	return blob_2
end

function create_health_up_item(x, y)
	health_up = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {full_heart_sprite},
		is_animated = false,
		should_remove = false,
	}

	function health_up:update()
		if sprites_collide(self, player) then
			sfx(2)

			self.should_remove = true
			player:heal()
		end
	end

	function health_up:draw()
		spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
	end

	return health_up
end

function create_speed_up_item(x, y)
	speed_up = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {increase_speed_sprite},
		is_animated = false,
		should_remove = false,
	}

	function speed_up:update()
		if sprites_collide(self, player) then
			sfx(2)

			self.should_remove = true
			player:increase_speed()
		end
	end

	function speed_up:draw()
		spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
	end

	return speed_up
end

function create_cooldown_down_item(x, y)
	cooldown_down = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {decrease_cooldown_sprite},
		is_animated = false,
		should_remove = false,
	}

	function cooldown_down:update()
		if sprites_collide(self, player) then
			sfx(2)

			self.should_remove = true
			player:decrease_cooldown_duration()
		end
	end

	function cooldown_down:draw()
		spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
	end

	return cooldown_down
end

function create_explosion_spread_up_item(x, y)
	explosion_spread_up = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {increase_explosion_sprite},
		is_animated = false,
		should_remove = false,
	}

	function explosion_spread_up:update()
		if sprites_collide(self, player) then
			sfx(2)

			self.should_remove = true
			player:increase_explosion_spread()
		end
	end

	function explosion_spread_up:draw()
		spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
	end

	return explosion_spread_up
end

function create_bomb_drop_up_item(x, y)
	bomb_drop_up = {
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {increase_bombs_sprite},
		is_animated = false,
		should_remove = false,
	}

	function bomb_drop_up:update()
		if sprites_collide(self, player) then
			sfx(2)
			
			self.should_remove = true
			player:increase_bomb_drop_amount()
		end
	end

	function bomb_drop_up:draw()
		spr(self.frames[1], self.position[1] - 4, self.position[2] - 4)
	end

	return bomb_drop_up
end

function create_bomb(x, y)
	bomb = {
		flipped = false,
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {3, 4},
		countdown_time = bomb_countdown_time, 
		animation_time = 0,
		is_animated = true,
		should_remove = false
	}

	function bomb:update()
		continue_animation(self)

		self.countdown_time -= delta_time

		if self.countdown_time < 0 then
			sfx(1)
			
			self.should_remove = true

			add(current_items, create_detonation(self.position[1], self.position[2], player.explosion_spread))
		end
	end

	function bomb:draw()
		draw_sprite(self)
	end

	return bomb
end

function create_detonation(x, y, remaining_spread)
	detonation = {
		flipped = false,
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {6, 7},
		timer = 0,
		explosion_countdown_time = explosion_countdown_time,
		explosion_duration = explosion_duration,
		animation_time = 0,
		is_animated = true,
		has_not_spread = true,
		should_remove = false
	}

	function detonation:update()
		continue_animation(self)

		self.timer += delta_time

		if self.timer > self.explosion_countdown_time and self.has_not_spread then
			self.has_not_spread = false

			-- spread fire up, down, left and right
			next_spread = remaining_spread - 1 
			add(current_items, create_fire_plume(self.position[1], self.position[2] + 8, {0, 8}, next_spread))
			add(current_items, create_fire_plume(self.position[1], self.position[2] - 8, {0, -8}, next_spread))
			add(current_items, create_fire_plume(self.position[1] - 8, self.position[2], {-8, 0}, next_spread))
			add(current_items, create_fire_plume(self.position[1] + 8, self.position[2], {8, 0}, next_spread))
		elseif self.timer > self.explosion_duration then
			self.should_remove = true
		else
			-- damage player
			if sprites_collide(self, player) then
				player:damage()
			end

			-- remove rocks
			for rock in all(current_rocks) do
				if sprites_collide(self, rock) then
					rock:damage()
					self.should_propogate = false
				end
			end

			-- kill bad guys
			for enemy in all(current_enemies) do
  			if sprites_collide(self, enemy) then
					sfx(4)
					
					current_score += enemy.points
					enemy.should_remove = true
				end
			end
		end
	end

	function detonation:draw()
		draw_sprite(self)
	end

	return detonation
end

function create_fire_plume(x, y, direction, remaining_spread)
	fire_plume = {
		flipped = false,
		position = {x, y},
		hit_adjustments = {0, 8, 0, 8},
		frames = {6, 7},
		direction = direction,
		timer = 0,
		explosion_countdown_time = explosion_countdown_time,
		explosion_duration = explosion_duration,
		animation_time = 0,
		is_animated = true,
		should_propogate = true,
		has_not_spread = true,
		should_remove = false
	}

	function fire_plume:update()
		continue_animation(self)

		self.timer += delta_time

		if self.timer > self.explosion_countdown_time and self.has_not_spread then
			self.has_not_spread = false
			
			if remaining_spread > 0 and self.should_propogate then
				add(current_items, create_fire_plume(self.position[1] + self.direction[1], self.position[2] + self.direction[2], self.direction, remaining_spread - 1))
			end
		elseif self.timer > self.explosion_duration then
			self.should_remove = true
		else
			pos_x = self.position[1]
			pos_y = self.position[2]

			-- damage player
			if sprites_collide(self, player) then
				player:damage()
			end

			-- remove rocks
			for rock in all(current_rocks) do
				if sprites_collide(self, rock) then
					rock:damage()
					self.should_propogate = false
				end
			end

			-- kill bad guys
			for enemy in all(current_enemies) do
  			if sprites_collide(self, enemy) then
					sfx(4)

					current_score += enemy.points
					enemy.should_remove = true
				end
			end
		end
	end

	function fire_plume:draw()
		draw_sprite(self)
	end

	return fire_plume
end

function load_dungeon_section(y, x)
	current_section_y = y
	current_section_x = x

	-- cache whether each side has a wall, for quick collision detection
	can_move_to_section_up = true
	can_move_to_section_down = true
	can_move_to_section_left = true
	can_move_to_section_right = true
	
	if current_section_y == 0 then
		can_move_to_section_up = false
	end

	if current_section_y == (dungeon.sections_y - 1) then
		can_move_to_section_down = false
	end

	if current_section_x == 0 then
		can_move_to_section_left = false
	end

	if current_section_x == (dungeon.sections_x - 1) then
		can_move_to_section_right = false
	end

	-- cache objects from section
	section_index = (current_section_y * dungeon.sections_x) + current_section_x 
	
	current_floor_tiles = dungeon.floor_tiles[section_index]
	current_walls = dungeon.walls[section_index]
	current_rocks = dungeon.rocks[section_index]
	current_items = dungeon.items[section_index]
	current_bombs = dungeon.bombs[section_index]
	current_enemies = dungeon.enemies[section_index]

	-- prevent player from getting stuck on rock by removing any overlapping in new section
	for rock in all(current_rocks) do
		player_x_1 = player.position[1] + player.hit_adjustments[1]
		player_x_2 = player_x_1 + player.hit_adjustments[2]
		player_y_1 = player.position[2] + player.hit_adjustments[3]
		player_y_2 = player_y_1 + player.hit_adjustments[4]
		rock_x_1 = rock.position[1] + rock.hit_adjustments[1]
		rock_x_2 = rock_x_1 + rock.hit_adjustments[2]
		rock_y_1 = rock.position[2] + rock.hit_adjustments[3]
		rock_y_2 = rock_y_1 + rock.hit_adjustments[4]
		
		if (player_x_1 < rock_x_2) and (player_x_2 > rock_x_1) and (player_y_1 < rock_y_2) and (player_y_2 > rock_y_1) then
			rock.should_remove = true
		end
	end
end

function store_dungeon_section()
	section_index = (current_section_y * dungeon.sections_x) + current_section_x

	dungeon.walls[section_index] = current_walls
	dungeon.rocks[section_index] = current_rocks
	dungeon.items[section_index] = current_items
	dungeon.bombs[section_index] = current_bombs
	dungeon.enemies[section_index] = current_enemies
end

function start_game()
	setup_player()
	generate_dungeon()
end

function reset_game()
	playing_game = false

	if current_score > top_score then
		top_score = current_score
	end
	current_score = 0

	if current_floor > top_floor then
		top_floor = current_floor
	end
	current_floor = 1

	setup_player()
	generate_dungeon()

	playing_game = false

	-- generate random pattern for background
	current_floor_tiles = {}
	for row = 0, 15 do
		for column = 0, 15 do
			current_floor_tiles[(row * 16) + column] = background_tiles[flr(rnd(count(background_tiles))) + 1] 
		end
	end
end

-- ENTRYPOINT
-------------

function _init()
	reset_game()
end

-- UPDATE
---------

function _update()
	set_delta_time()

	if playing_game then
		player:update()
		update_dungeon()
	else 
		update_title_screen()
	end
end

function update_dungeon()
	for rock in all(current_rocks) do
  	rock:update()
	end

	for item in all(current_items) do
  	item:update()
	end

	for bomb in all(current_bombs) do
  	bomb:update()
	end

	for enemy in all(current_enemies) do
  	enemy:update()
	end

	-- remove lists in place, for speed improvement
	for i = 1, count(current_rocks) do
		if current_rocks[i] and current_rocks[i].should_remove then
			-- for adding item
			x = current_rocks[i].position[1]
			y = current_rocks[i].position[2]
			
			for j = i, (count(current_rocks) - 1) do
				current_rocks[j] = current_rocks[j + 1]
			end
			current_rocks[count(current_rocks)] = nil

			if flr(rnd(50)) == 0 then
				add(current_items, create_health_up_item(x, y))
			elseif flr(rnd(50)) == 0 then
				add(current_items, create_speed_up_item(x, y))
			elseif flr(rnd(50)) == 0 then
				add(current_items, create_cooldown_down_item(x, y))
			elseif flr(rnd(100)) == 0 then
				add(current_items, create_explosion_spread_up_item(x, y))
			elseif flr(rnd(200)) == 0 then
				add(current_items, create_bomb_drop_up_item(x, y))
			end
		end
	end
	
	for i = 1, count(current_items) do
		if current_items[i] and current_items[i].should_remove then
			for j = i, (count(current_items) - 1) do
				current_items[j] = current_items[j + 1]
			end
			current_items[count(current_items)] = nil
		end
	end

	for i = 1, count(current_bombs) do
		if current_bombs[i] and current_bombs[i].should_remove then
			for j = i, (count(current_bombs) - 1) do
				current_bombs[j] = current_bombs[j + 1]
			end
			current_bombs[count(current_bombs)] = nil
		end
	end

	for i = 1, count(current_enemies) do
		if current_enemies[i] and current_enemies[i].should_remove then
			for j = i, (count(current_enemies) - 1) do
				current_enemies[j] = current_enemies[j + 1]
			end
			current_enemies[count(current_enemies)] = nil
		end
	end

	reveal_exit_if_no_enemies()
end

function update_title_screen()
	if btn(0) or btn(1) or btn(2) or btn(3) or btn(4) or btn(5) or btn(6) then
		playing_game = true
		start_game()
	end 
end

-- DRAW
-------

function _draw()
	cls()

	if playing_game then
		draw_dungeon_section(0, 0)
		player:draw()
		draw_ui()
	else
		draw_title_screen()
	end
end

function draw_dungeon_section(section_row, section_column)
	for row = 0, 15 do
		for column = 0, 15 do
			spr(current_floor_tiles[(row * 16) + column], row * 8, column * 8)
		end
	end

	for wall in all(current_walls) do
  	wall:draw()
	end

	if dungeon.exit[1] == current_section_x and dungeon.exit[2] == current_section_y then
		spr(exit_tile, dungeon.exit[3] - 4, dungeon.exit[4] - 4)
	end

	for rock in all(current_rocks) do
  	rock:draw()
	end

	for item in all(current_items) do
  	item:draw()
	end

	for bomb in all(current_bombs) do
  	bomb:draw()
	end

	for enemy in all(current_enemies) do
  	enemy:draw()
	end
end

function draw_ui()
	-- health
	if player.health >= 3 then
		spr(full_heart_sprite, 0, 0)
	else
		spr(empty_heart_sprite, 0, 0)
	end

	if player.health >= 2 then
		spr(full_heart_sprite, 8, 0)
	else
		spr(empty_heart_sprite, 8, 0)
	end

	spr(full_heart_sprite, 16, 0)

	-- stats
	print("lvl:"..tostr(current_floor).."  scr:"..tostr(current_score).."", 33, 1, 10)
	
	-- bomb recharge
	charged_amount = 30
	charging_amount = 0
	if player.cooldown_timer > 0 then
		charging_amount = flr((player.cooldown_timer / player.cooldown_duration) * 30)
		charged_amount = flr(30 - charging_amount)
	end

	rect(96, 3, 96 + charged_amount - 1, 4, 10)
	if charging_amount > 0 then
		rect(96 + charged_amount, 3, 96 + charged_amount + charging_amount - 1, 4, 13)
	end
end

function draw_title_screen()
	for row = 0, 15 do
		for column = 0, 15 do
			spr(current_floor_tiles[(row * 16) + column], row * 8, column * 8)
		end
	end

	print("miner man", 48, 40, 10)
	print("top score: "..tostr(top_score), 40, 56, 10)
	print("top floor: "..tostr(top_floor), 40, 64, 10)
	print("press x or arrows to play", 16, 80, 10)

	print("arrows move, z drops bomb", 16, 104, 6)
end

-- CORE
-------

function set_delta_time()
	previous_time = current_time
	current_time = time()
	delta_time = current_time - previous_time
end

function move_sprite(sprite, x, y)
	can_move = true
	
	sprite_new_x_1 = x + sprite.hit_adjustments[1]
	sprite_new_x_2 = sprite_new_x_1 + sprite.hit_adjustments[2]
	sprite_new_y_1 = y + sprite.hit_adjustments[3]
	sprite_new_y_2 = sprite_new_y_1 + sprite.hit_adjustments[4]

	if sprite.is_enemy then
		if (can_move_to_section_up == false and sprite_new_y_1 < 12) or (sprite_new_y_1 < 0) then
			can_move = false
		end

		if (can_move_to_section_down == false and sprite_new_y_2 > 124) or (sprite_new_y_2 > 128) then
			can_move = false
		end

		if (can_move_to_section_right == false and sprite_new_x_2 > 124) or (sprite_new_x_2 > 128) then
			can_move = false
		end

		if (can_move_to_section_left == false and sprite_new_x_1 < 12) or (sprite_new_x_1 < 0) then
			can_move = false
		end
	else
		if can_move_to_section_up == false and sprite_new_y_1 < 12 then
			can_move = false
		end

		if can_move_to_section_down == false and sprite_new_y_2 > 124 then
			can_move = false
		end

		if can_move_to_section_right == false and sprite_new_x_2 > 124 then
			can_move = false
		end

		if can_move_to_section_left == false and sprite_new_x_1 < 12 then
			can_move = false
		end
	end

	for rock in all(current_rocks) do
		rock_b_x_1 = rock.position[1] + rock.hit_adjustments[1]
		rock_b_x_2 = rock_b_x_1 + rock.hit_adjustments[2]
		rock_b_y_1 = rock.position[2] + rock.hit_adjustments[3]
		rock_b_y_2 = rock_b_y_1 + rock.hit_adjustments[4]

		if (sprite_new_x_1 < rock_b_x_2) and (sprite_new_x_2 > rock_b_x_1) and (sprite_new_y_1 < rock_b_y_2) and (sprite_new_y_2 > rock_b_y_1) then
			can_move = false
		end
	end

	if sprite.collides_with_bombs then
		for bomb in all(current_bombs) do
			bomb_b_x_1 = bomb.position[1] + bomb.hit_adjustments[1]
			bomb_b_x_2 = bomb_b_x_1 + bomb.hit_adjustments[2]
			bomb_b_y_1 = bomb.position[2] + bomb.hit_adjustments[3]
			bomb_b_y_2 = bomb_b_y_1 + bomb.hit_adjustments[4]

			if (sprite_new_x_1 < bomb_b_x_2) and (sprite_new_x_2 > bomb_b_x_1) and (sprite_new_y_1 < bomb_b_y_2) and (sprite_new_y_2 > bomb_b_y_1) then
				can_move = false
			end
		end
	end

	if can_move then
		sprite.position[1] = x
		sprite.position[2] = y
	end

	return can_move
end

function sprites_collide(sprite_a, sprite_b)
	sprite_a_x_1 = sprite_a.position[1] + sprite_a.hit_adjustments[1]
	sprite_a_x_2 = sprite_a_x_1 + sprite_a.hit_adjustments[2]
	sprite_a_y_1 = sprite_a.position[2] + sprite_a.hit_adjustments[3]
	sprite_a_y_2 = sprite_a_y_1 + sprite_a.hit_adjustments[4]
	sprite_b_x_1 = sprite_b.position[1] + sprite_b.hit_adjustments[1]
	sprite_b_x_2 = sprite_b_x_1 + sprite_b.hit_adjustments[2]
	sprite_b_y_1 = sprite_b.position[2] + sprite_b.hit_adjustments[3]
	sprite_b_y_2 = sprite_b_y_1 + sprite_b.hit_adjustments[4]
	if (sprite_a_x_1 < sprite_b_x_2) and (sprite_a_x_2 > sprite_b_x_1) and (sprite_a_y_1 < sprite_b_y_2) and (sprite_a_y_2 > sprite_b_y_1) then
		return true
	else
		return false
	end
end

function draw_sprite(sprite)
	spr(get_sprite_frame(sprite), sprite.position[1] - 4, sprite.position[2] - 4, 1, 1, sprite.flipped)
end

function continue_animation(sprite)
	sprite.is_animated = true
	sprite.animation_time += delta_time
end

function stop_animation(sprite)
	sprite.is_animated = false
	sprite.animation_time = base_animation_duration
end

function get_sprite_frame(sprite)
	if sprite.is_animated then
		return sprite.frames[flr(sprite.animation_time / base_animation_duration) % (count(sprite.frames)) + 1]
	else
		return sprite.frames[1]
	end
end

function center_sprite_coord(coord_value)
	-- sprites are centered in 8x8 cells, so multiple of 4 is in center
	coord_remainder = coord_value % 4
	if coord_remainder > 2 then
		next_multiple_of_four = coord_value + (4 - coord_remainder)
		if next_multiple_of_four % 8 == 0 then
			return coord_value - coord_remainder
		else
			return next_multiple_of_four
		end
	else
		next_multiple_of_four = coord_value - coord_remainder
		if next_multiple_of_four % 8 == 0 then
			return coord_value + (4 - coord_remainder)
		else
			return next_multiple_of_four
		end
	end
end

function see_sprite_up(enemy, sprite)
	in_line_of_sight = false
	
	sprite_x_1 = sprite.position[1] + sprite.hit_adjustments[1]
	sprite_x_2 = sprite_x_1 + sprite.hit_adjustments[2]
	enemy_x_1 = enemy.position[1] + 3
	enemy_x_2 = enemy_x_1 + 2

	-- overlaps vertically
	if (sprite_x_1 < enemy_x_2) and (sprite_x_2 > enemy_x_1) then
		-- must be above
		if sprite.position[2] <= enemy.position[2] then
			return true
		end
	end

	return false
end

function see_sprite_down(enemy, sprite)
	in_line_of_sight = false
	
	sprite_x_1 = sprite.position[1] + sprite.hit_adjustments[1]
	sprite_x_2 = sprite_x_1 + sprite.hit_adjustments[2]
	enemy_x_1 = enemy.position[1] + 3
	enemy_x_2 = enemy_x_1 + 2

	-- overlaps vertically
	if (sprite_x_1 < enemy_x_2) and (sprite_x_2 > enemy_x_1) then
		-- must be below
		if sprite.position[2] >= enemy.position[2] then
			return true
		end
	end

	return false
end

function see_sprite_left(enemy, sprite)
	in_line_of_sight = false
	
	sprite_y_1 = sprite.position[2] + sprite.hit_adjustments[3]
	sprite_y_2 = sprite_y_1 + sprite.hit_adjustments[4]
	enemy_y_1 = enemy.position[2] + 3
	enemy_y_2 = enemy_y_1 + 2

	-- overlaps horizontally
	if (sprite_y_1 < enemy_y_2) and (sprite_y_2 > enemy_y_1) then
		-- must be to left
		if sprite.position[1] <= enemy.position[1] then
			return true
		end
	end

	return false
end

function see_sprite_right(enemy, sprite)
	in_line_of_sight = false
	
	sprite_y_1 = sprite.position[2] + sprite.hit_adjustments[3]
	sprite_y_2 = sprite_y_1 + sprite.hit_adjustments[4]
	enemy_y_1 = enemy.position[2] + 3
	enemy_y_2 = enemy_y_1 + 2

	-- overlaps horizontally
	if (sprite_y_1 < enemy_y_2) and (sprite_y_2 > enemy_y_1) then
		-- must be to right
		if sprite.position[1] >= enemy.position[1] then
			return true
		end
	end

	return false
end

function reveal_exit_if_no_enemies()
	if dungeon.exit_not_shown and count(current_enemies) == 0 then
		dungeon.exit_not_shown = false
		
		store_dungeon_section()

		section_index = (dungeon.exit[2] * dungeon.sections_x) + dungeon.exit[1]

		exit_x_1 = dungeon.exit[3]
		exit_x_2 = exit_x_1 + 8
		exit_y_1 = dungeon.exit[4]
		exit_y_2 = exit_y_1 + 8

		for rock in all(dungeon.rocks[section_index]) do
			rock_x_1 = rock.position[1] + rock.hit_adjustments[1]
			rock_x_2 = rock_x_1 + rock.hit_adjustments[2]
			rock_y_1 = rock.position[2] + rock.hit_adjustments[3]
			rock_y_2 = rock_y_1 + rock.hit_adjustments[4]
			
			if (exit_x < rock_x_2) and (exit_x_2 > rock_x_1) and (exit_y_1 < rock_y_2) and (exit_y_2 > rock_y_1) then
				rock.should_remove = true
			end
		end

		load_dungeon_section(current_section_y, current_section_x)
	end
end

__gfx__
00000000000090000000900000000000000000000000000008080808808080800000000000000000000000000000000000000000000000000000800000008000
000000000009a0000009a00000000000000009000000000088888880088888880000000000000000000000000000000000000000000000000008800000088000
00700700000ff000000ff00f000098000000a0000000000008899888888998800000000000000000000000000000000000000000000000000008800000088008
0007700007977970079779700007000000070000000000008899a980089a99880000000000000000000000000000000000000000000000000888888008888880
000770000f9999f0f0999900000110000001100000000000089a99888899a9800000000000000000000000000000000000000000000000000888888080888800
007007000099990000999900001d1100001d11000000000088899880088998880000000000000000000000000000000000000000000000000088880000888800
00000000009009000900009000111100001111000000000008888888888888800000000000000000000000000000000000000000000000000080080008000080
00000000005005005000005000011000000110000000000080808080080808080000000000000000000000000000000000000000000000000080080080000080
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444464444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
4444b444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
00555500002222000022120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444411111111
0555555002222220022212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000449dd94411111111
555d5555222e2222222e212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d9999d411111111
5555555522222222212222210000aaa00000aa000000000000000000000000000000000000000000000000000000000000000000000000004d9dd9d41111d111
555555552222222222122212000a8a80000a8aa00000000000000000000000000000000000000000000000000000000000000000000000004d9dd9d4111d1111
555555552222222221222122000aaaa0000aaa800000000000000000000000000000000000000000000000000000000000000000000000004d9999d411111111
05555550022222200222222000aaaaaa00aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000449dd94411111111
0055550000222200002222000aaaaaa000aaaaa00000000000000000000000000000000000000000000000000000000000000000000000004444444411111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ccc00000cc000000000000000000000000000000000000000000000000000000000000000000005555000000000000000000000070000000000000000000
000c8c80000c8cc00000000000000000000000000000000000000000000000000000000000000000057777500000000000000000007070000060060000800800
000cccc0000ccc800000000000000000000000000000000000000000000000000000000000000000057667500090009000088000007055000666666008888880
00cccccc00ccccc00000000000000000000000000000000000000000000000000000000000000000057677500090090000899800001165500066660000888800
0cccccc000ccccc000000000000000000000000000000000000000000000000000000000000000000577775000905000089aa98001d115500006600000088000
00000000000000000000000000000000000000000000000000000000000000000000000000000000005555000090050000899800011115000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055000000088000001100000000000000000000
0000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000200001b15023150261501010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c000019654096500e6500a65006650006000060001600066000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006000017150281502f1500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000184501e4501c45019450164500c4500940006400034000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001b5101e550215501b55014550125500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006000027000200001a000130000d000050000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41024344
00 01024304
00 01424304
00 01424344
00 01024304
00 01020344

