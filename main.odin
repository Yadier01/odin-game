package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rb "vendor:raylib"


entity :: enum {
	PLAYER,
	ENEMY,
	BULLET,
}

player_action_state :: enum {
	IDLE,
	ATTACK,
}

Vec2 :: [2]f32
player :: struct {
	pos:                 Vec2,
	size:                Vec2,
	color:               rb.Color,
	player_center:       Vec2,
	player_action_state: player_action_state,
	health:              i32,
	entity:              entity,
}
bullet :: struct {
	x, y:             f32,
	width, height:    i32,
	color:            rb.Color,
	speed:            f32,
	isAlive:          bool,
	aliveTime:        f32,
	speed_x, speed_y: f32,
	entity:           entity,
}
Enemy :: struct {
	x, y:          f32,
	width, height: i32,
	color:         rb.Color,
	health:        i32,
	speed:         f32,
	enemy_center:  rb.Vector2,
	entity:        entity,
}


gameState :: struct {
	player:  player,
	enemy:   [dynamic]Enemy,
	bullets: [dynamic]bullet,
}

speed: f32 = 500
deltaTime: f32 = 0
game_state: gameState
shoot_cooldown: f32 = 0
shoot_delay: f32 = 0.1
time: f32 = 0.0
time_enemy_shoot: f32 = 0.0

player_bullet := bullet {
	width  = 10,
	height = 10,
	color  = rb.GREEN,
	speed  = 300,
	entity = entity.PLAYER,
}
main :: proc() {

	rb.SetConfigFlags({rb.ConfigFlag.VSYNC_HINT, rb.ConfigFlag.WINDOW_RESIZABLE})
	rb.InitWindow(800, 600, "Raylib")
	defer rb.CloseWindow()

	player: player = {
		pos    = Vec2{200, 200},
		size   = Vec2{20, 20},
		color  = rb.RED,
		health = 100,
		entity = entity.PLAYER,
	}

	game_state = {
		player  = player,
		enemy   = make([dynamic]Enemy),
		bullets = make([dynamic]bullet),
	}

	enemyS: Enemy = {
		x      = 300,
		y      = 300,
		width  = 30,
		height = 30,
		health = 100,
		speed  = 100,
		color  = rb.GREEN,
		entity = entity.ENEMY,
	}

	append(&game_state.enemy, enemyS)

	for !rb.WindowShouldClose() {
		rb.BeginDrawing()

		deltaTime = rb.GetFrameTime()

		handle_input()

		rb.DrawRectangle(
			auto_cast game_state.player.pos.x,
			auto_cast game_state.player.pos.y,
			auto_cast game_state.player.size.x,
			auto_cast game_state.player.size.y,
			game_state.player.color,
		)

		mouse_position := rb.GetMousePosition()
		switch game_state.player.player_action_state {
		case player_action_state.ATTACK:
			if shoot_cooldown <= 0 {
				shoot_cooldown = shoot_delay
				player_attack(mouse_position)
			}

		case player_action_state.IDLE:
			shoot_cooldown = 0
		}

		shoot_cooldown -= deltaTime
		time_enemy_shoot += deltaTime
		time += deltaTime

		enemy_shoot()

		add_enemy()
		update_bullet()
		update_enemy()

		rb.ClearBackground(rb.RAYWHITE)
		rb.EndDrawing()
	}
	delete(game_state.bullets)
	delete(game_state.enemy)
}
player_attack :: proc(mouse_position: rb.Vector2) {
	game_state.player.player_center = get_center_rect(
		game_state.player.pos.x,
		game_state.player.pos.y,
		auto_cast game_state.player.size.x,
		auto_cast game_state.player.size.y,
	)

	//set the  bullet starting positon to be the center of the player
	player_bullet.x = game_state.player.player_center.x
	player_bullet.y = game_state.player.player_center.y
	player_bullet.isAlive = true
	player_bullet.aliveTime = 0


	calc_dir_and_apply_speed(
		game_state.player.player_center,
		rb.Vector2{f32(mouse_position.x), f32(mouse_position.y)},
		&player_bullet,
	)
	append(&game_state.bullets, player_bullet)

}
get_center_rect :: proc(x: f32, y: f32, width: f32, height: f32) -> rb.Vector2 {
	return rb.Vector2{x + width / 2, y + height / 2}
}

enemy_shoot :: proc() {
	if time_enemy_shoot > .5 {
		time_enemy_shoot = 0
		for &enemy in game_state.enemy {
			enemy_bullet := generate_enemy_bullet()
			enemy.enemy_center = get_center_rect(
				enemy.x,
				enemy.y,
				auto_cast enemy.width,
				auto_cast enemy.height,
			)

			enemy_bullet.x = enemy.enemy_center.x
			enemy_bullet.y = enemy.enemy_center.y
			enemy_bullet.isAlive = true
			enemy_bullet.aliveTime = 0

			calc_dir_and_apply_speed(
				enemy.enemy_center,
				rb.Vector2{f32(game_state.player.pos.x), f32(game_state.player.pos.y)},
				&enemy_bullet,
			)
			append(&game_state.bullets, enemy_bullet)
		}
	}
}
calc_dir_and_apply_speed :: proc(calc_from: rb.Vector2, calc_to: rb.Vector2, bullet: ^bullet) {
	// Calculate direction from source to target
	dx := calc_to.x - calc_from.x
	dy := calc_to.y - calc_from.y
	length := math.hypot(dx, dy)

	// Normalize direction and apply speed
	bullet.speed_x = (dx / length) * bullet.speed
	bullet.speed_y = (dy / length) * bullet.speed
}
check_collision :: proc(bullet: ^bullet) {
	for &enemy, j in game_state.enemy {
		#partial switch bullet.entity {

		// Check collision when enemy hits player
		case entity.ENEMY:
			if rb.CheckCollisionCircleRec(
				rb.Vector2{bullet.x, bullet.y},
				10,
				rb.Rectangle {
					game_state.player.pos.x,
					game_state.player.pos.y,
					f32(game_state.player.size.x),
					f32(game_state.player.size.y),
				},
			) {
				game_state.player.health -= 10
				bullet.isAlive = false

				if game_state.player.health <= 0 {
					fmt.println("player killed")
				}
			}

		// Check collision when player hits enemy
		case entity.PLAYER:
			if rb.CheckCollisionCircleRec(
				rb.Vector2{bullet.x, bullet.y},
				10,
				rb.Rectangle{enemy.x, enemy.y, f32(enemy.width), f32(enemy.height)},
			) {
				bullet.isAlive = false
				enemy.health -= 10
				if enemy.health <= 0 {
					fmt.println("enemy killed")
					ordered_remove(&game_state.enemy, j)
				}
			}
		}

	}


}

add_enemy :: proc() {
	if time > 3.0 {
		enemy: Enemy = {
			x      = rand.float32_range(0, 800),
			y      = rand.float32_range(0, 600),
			width  = 30,
			height = 30,
			health = 100,
			speed  = 100,
			color  = rb.GREEN,
		}
		append(&game_state.enemy, enemy)
		time = 0
	}
}

update_enemy :: proc() {
	// Calculate direction to player
	for &enemy in game_state.enemy {
		dx := f32(game_state.player.pos.x) - enemy.x
		dy := f32(game_state.player.pos.y) - enemy.y
		length := math.hypot(dx, dy)

		// Normalize direction and apply speed
		enemy.x += (dx / length) * enemy.speed * deltaTime
		enemy.y += (dy / length) * enemy.speed * deltaTime

		rb.DrawRectangle(
			auto_cast enemy.x,
			auto_cast enemy.y,
			enemy.width,
			enemy.height,
			enemy.color,
		)
	}
}

handle_input :: proc() {
	if rb.IsKeyDown(rb.KeyboardKey.W) {
		game_state.player.pos.y -= speed * deltaTime
	}
	if rb.IsKeyDown(rb.KeyboardKey.S) {
		game_state.player.pos.y += speed * deltaTime
	}
	if rb.IsKeyDown(rb.KeyboardKey.A) {
		game_state.player.pos.x -= speed * deltaTime
	}
	if rb.IsKeyDown(rb.KeyboardKey.D) {
		game_state.player.pos.x += speed * deltaTime
	}

	if rb.IsMouseButtonDown(rb.MouseButton.LEFT) {
		game_state.player.player_action_state = player_action_state.ATTACK
	} else {
		game_state.player.player_action_state = player_action_state.IDLE
	}
}

update_bullet :: proc() {
	for &bullet, i in game_state.bullets {
		bullet.aliveTime += deltaTime

		if bullet.aliveTime > 3 {
			bullet.isAlive = false
		}
		if !bullet.isAlive {
			ordered_remove(&game_state.bullets, i)
			continue
		}

		bullet.x += bullet.speed_x * deltaTime
		bullet.y += bullet.speed_y * deltaTime
		rb.DrawCircle(auto_cast bullet.x, auto_cast bullet.y, 10, bullet.color)

		check_collision(&bullet)

	}
}

generate_enemy_bullet :: proc() -> bullet {
	enemy_bullet: bullet = {
		x      = 0,
		y      = 0,
		width  = 10,
		height = 10,
		color  = rb.RED,
		speed  = 300,
		entity = entity.ENEMY,
	}
	return enemy_bullet
}
