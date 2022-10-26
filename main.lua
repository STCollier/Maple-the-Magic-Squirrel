local sti = require "libraries/sti"
local cam = require "libraries/camera"
local anim8 = require "libraries/anim8"

function love.load()
    map = sti("maps/map.lua")
	camera = cam()

	--love.window.setFullscreen(true)
	
	windowWidth = love.graphics.getWidth()
	windowHeight = love.graphics.getHeight()
	mapScale = 2;
	mapW = (map.width * map.tilewidth)*mapScale
	mapH = (map.height * map.tileheight)*mapScale

	currentScene = "Start"
	titleRotation = 5
	titleRotationSpeed = 0.1

	local str = love.filesystem.read('shader.frag')
    shader = love.graphics.newShader(str)

	font = love.graphics.newFont("font.ttf")
	love.graphics.setFont(font, 20)

	mainSong = love.audio.newSource("main_song.ogg", "stream")
	mainSong:setLooping(true)
	love.audio.play(mainSong)
	buttonBeep = love.audio.newSource("button_beep.mp3", "static")
	buttonBeep:setVolume(0.2)
	whooshSound = love.audio.newSource("whoosh.mp3", "static")
	whooshSound:setVolume(0.5)
	deathSound = love.audio.newSource("death.mp3", "static")
	deathSound:setVolume(0.5)
	jumpSound = love.audio.newSource("jump.mp3", "static")

	world = love.physics.newWorld(0, 500)
	love.physics.setMeter(64)
	love.graphics.setDefaultFilter("nearest", "nearest")
	world:setCallbacks(beginContact)

	startsceneTitleImg = love.graphics.newImage("sprites/startscene_title.png")
	startscenePlaybtnImg = love.graphics.newImage("sprites/startscene_playbtn.png")
	startsceneExitbtnImg = love.graphics.newImage("sprites/startscene_exitbtn.png")
	startsceneCreditsImg = love.graphics.newImage("sprites/credits.png")

	local particleImg = love.graphics.newImage("sprites/particle.png")
	psystem = love.graphics.newParticleSystem(particleImg, 32)
	psystem:setParticleLifetime(2, 3.5)
	psystem:setEmissionRate(10)
	psystem:setSizeVariation(1)
	psystem:setLinearAcceleration(-80, -80, 80, 80) -- Random movement in all directions.
	psystem:setColors(1, 1, 1, 1, 1, 1, 1, 0) -- Fade to transparency.

	local leafParticleImg = love.graphics.newImage("sprites/falling_leaf.png")
	leafpsystem = love.graphics.newParticleSystem(leafParticleImg, 32)
	leafpsystem:setParticleLifetime(7, 10)
	leafpsystem:setEmissionRate(10)
	leafpsystem:setSizeVariation(1)
	leafpsystem:setLinearAcceleration(-200, -200, 200, 200) -- Random movement in all directions.
	leafpsystem:setColors(1, 1, 1, 1, 1, 1, 1, 0) -- Fade to transparency.
	leafpsystem:setSpin(1, 5)

	bgImg = love.graphics.newImage("sprites/parallax-forest-back-trees.png")
	uiBarImg = love.graphics.newImage("sprites/ui_bar.png")

    player = {}
	player.leaf = love.graphics.newImage("sprites/leaf.png")
	player.spritesheet = love.graphics.newImage("sprites/player_spritesheet.png")
	player.animGrid = anim8.newGrid(32, 32, player.spritesheet:getWidth(), player.spritesheet:getHeight())
	player.animations = {}
	player.animations.idleRight = anim8.newAnimation(player.animGrid('1-6', 1), 0.1)
	player.animations.runRight = anim8.newAnimation(player.animGrid('1-8', 3), 0.1)
	player.animations.runLeft = anim8.newAnimation(player.animGrid('1-8', 3), 0.1)
	player.animations.idleLeft = anim8.newAnimation(player.animGrid('1-6', 1), 0.1)
	player.animations.runLeft:flipH()
	player.animations.idleLeft:flipH()
	player.anim = player.animations.idleRight
	if (map.layers["Player Spawn"]) then
		for i, obj in pairs(map.layers["Player Spawn"].objects) do
			player.x = (obj.x*mapScale)
			player.y = (obj.x*mapScale) + mapH - 400
		end
	end
	player.w = 75
	player.h = 55
	player.isALeaf = false
	player.dir = nil
	player.maxVelX = 300
	player.maxVelY = 500
	player.speed = 700
	player.canJump = true
	player.jumpForce = 600
	player.body = love.physics.newBody(world, player.x, player.y, "dynamic")
	player.shape = love.physics.newRectangleShape(player.w, player.h)
	player.fixture = love.physics.newFixture(player.body, player.shape)
	player.died = false
	player.fixture:setUserData("Player")
	player.body:setFixedRotation(true)

	leafUI = {}
	leafUI.w = 300
	leafUI.speed = 0.5

	walls = {}
	if (map.layers["Solid Colliders"]) then
		for i, obj in pairs(map.layers["Solid Colliders"].objects) do
			--local wall = love.physics.newBody(world, obj.x, obj.y, "static")
			--table.insert(walls, wall)
			walls.body = love.physics.newBody(world, (obj.x+obj.width/2)*mapScale, (obj.y+obj.height/2)*mapScale, "static")
			walls.shape = love.physics.newRectangleShape(obj.width*mapScale, obj.height*mapScale)
			walls.fixture = love.physics.newFixture(walls.body, walls.shape)
		end
	end

	spikes = {}
	if (map.layers["Spike Colliders"]) then
		for i, obj in pairs(map.layers["Spike Colliders"].objects) do
			--local wall = love.physics.newBody(world, obj.x, obj.y, "static")
			--table.insert(walls, wall)
			spikes.body = love.physics.newBody(world, (obj.x+obj.width/2)*mapScale, (obj.y+obj.height/2)*mapScale, "static")
			spikes.shape = love.physics.newRectangleShape(obj.width*mapScale, obj.height*mapScale)
			spikes.fixture = love.physics.newFixture(spikes.body, spikes.shape)
			spikes.fixture:setUserData("Spikes")
		end
	end

	text = {}
	if (map.layers["Text"]) then
		for i, obj in pairs(map.layers["Text"].objects) do
			table.insert(text, obj)
		end
	end

end

function love.update(dt)
	player.velX, player.velY = player.body:getLinearVelocity()
	-- Get width/height of background
	local isMoving = false

	if love.keyboard.isDown("escape") and currentScene == "Game" then
		currentScene = "Start"
	end

	if currentScene == "Game" then
		if love.keyboard.isDown("right") then
			player.dir = "right"
			player.anim = player.animations.runRight
			isMoving = true
		end
		if love.keyboard.isDown("left") then
			player.dir = "left"
			player.anim = player.animations.runLeft
			isMoving = true
		end

		if love.keyboard.isDown("right") and not player.isALeaf and player.velX < player.maxVelX then
			player.body:applyForce(player.speed, 0)
		end
		if love.keyboard.isDown("left") and not player.isALeaf and player.velX > -player.maxVelX then
			player.body:applyForce(-player.speed, 0)
		end

		if love.keyboard.isDown("right") and player.isALeaf then
			player.body:applyForce(player.speed*3, 0)
		elseif love.keyboard.isDown("left") and player.isALeaf then
			player.body:applyForce(-player.speed*3, 0)
		end

		if isMoving == false then
			if player.dir == "right" then
				player.anim = player.animations.idleRight
			end
			if player.dir == "left" then
				player.anim = player.animations.idleLeft
			end
		end

		camera:lookAt(player.body:getX(), player.body:getY())

		if camera.x < windowWidth/2 then
			camera.x = windowWidth/2
		end
		if camera.y < windowHeight/2 then
			camera.y = windowHeight/2
		end

		if camera.x > (mapW - windowWidth/2) then
			camera.x = (mapW - windowWidth/2)
		end
		if camera.y > (mapH - windowHeight/2) then
			camera.y = (mapH - windowHeight/2)
		end

		if (player.velY == 0) then
			player.canJump = true
		end

		if leafUI.w <= 0 then
			player.isALeaf = false
			leafUI.w = 0
		end

		if player.died then
			love.audio.play(deathSound)
			leafUI.w = 300
			player.isALeaf = false
			player.body:setPosition(player.x, player.y-player.h*2)
			player.velX = 0
			player.died = false
		end

		player.body:setLinearVelocity(math.min(player.velX, player.maxVelX), math.min(player.velY, player.maxVelY))
		psystem:update(dt)
		leafpsystem:update(dt)
		player.anim:update(dt)
		world:update(dt)
	end
end

function love.draw()

	love.graphics.setShader(shader)
	love.graphics.draw(bgImg, 0, 0, nil, 6)

	if currentScene == "Game" then
		drawGameScene()
	end
	if currentScene == "Start" then
		drawStartScene()
	end
end

function love.keypressed(key)
	if key == "up" and player.canJump and not player.isALeaf and currentScene == "Game" then
		player.body:applyLinearImpulse(0, -player.jumpForce)
		player.canJump = false
		love.audio.play(jumpSound)
	end

	if key == "space" and currentScene == "Game" then
		if not player.isALeaf then 
			player.isALeaf = true
			love.audio.play(whooshSound)
		else
			player.isALeaf = false 
			love.audio.play(whooshSound)
		end
	end

end

function beginContact(a, b, coll)
	if a:getUserData() == "Player" and b:getUserData() == "Spikes" then
		player.died = true
	end
end

function drawGameScene()
	camera:attach()
		love.graphics.push()
		love.graphics.scale(mapScale)
		--map:drawLayer(map.layers["Player Spawn"])
		--map:drawLayer(map.layers["Solids"])
		map:drawLayer(map.layers["Background Blocks"])
		map:drawLayer(map.layers["Main Blocks"])
		map:drawLayer(map.layers["Spikes"])
		love.graphics.pop()

		--Draw hitbox (optional)
		--love.graphics.polygon("fill", player.body:getWorldPoints(player.shape:getPoints()))

		--Allign hitbox/player body to animation
		if not player.isALeaf then
			player.anim:draw(player.spritesheet, player.body:getX()-player.w-5, player.body:getY()-player.h-75, nil, 5, 5)
			player.body:setLinearDamping(0)
			player.maxVelX = 400
		else
			leafUI.w = leafUI.w - leafUI.speed
			love.graphics.draw(psystem, player.body:getX(), player.body:getY(), 2, 2)
			love.graphics.draw(player.leaf, player.body:getX()-player.w/2, player.body:getY()-player.h/2-15, nil, 3, 3)
			player.body:setLinearDamping(9)
			player.maxVelX = 1000
		end

		love.graphics.push()
		love.graphics.scale(mapScale)
		map:drawLayer(map.layers["Trees"])

		love.graphics.setColor(0, 0, 0, 255)
		love.graphics.print("Press 'SPACE' to turn into a leaf and float", text[2].x, text[2].y)
		love.graphics.print("The bar at the top shows how much magic you have.", text[1].x, text[1].y)
		love.graphics.print("Thanks for playing!", text[3].x+15, text[3].y+10)
		love.graphics.setColor(1, 1, 1)
		love.graphics.pop()
	camera:detach()
	
	love.graphics.draw(leafpsystem, -20, -20, 2, 2)

	love.graphics.setColor(love.math.colorFromBytes(100, 50, 0))
	love.graphics.rectangle("fill", 25, 25, leafUI.w, 50)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(uiBarImg, 25, 25, nil, 5)
end

function drawStartScene()
	love.graphics.draw(startsceneTitleImg, windowWidth/2, 150, math.rad(titleRotation), 1, 1, startsceneTitleImg:getWidth()/2, startsceneTitleImg:getHeight()/2)

	if titleRotation >= 5 then
		titleRotationSpeed = -titleRotationSpeed
	end
	if titleRotation <= -5 then
		titleRotationSpeed = -titleRotationSpeed
	end

	titleRotation = titleRotation + titleRotationSpeed

	love.graphics.draw(startscenePlaybtnImg, windowWidth/2-startscenePlaybtnImg:getWidth()/2, 450)
	love.graphics.draw(startsceneExitbtnImg, windowWidth/2-startsceneExitbtnImg:getWidth()/2, 500+startscenePlaybtnImg:getHeight())

	if love.mouse.getX() > windowWidth/2-startscenePlaybtnImg:getWidth()/2 and love.mouse.getX() < windowWidth/2+startscenePlaybtnImg:getWidth()/2
	and love.mouse.getY() > 450 and love.mouse.getY() < 450+startscenePlaybtnImg:getHeight() and love.mouse.isDown(1) then
		currentScene = "Game"
		love.audio.play(buttonBeep)
	end

	if love.mouse.getX() > windowWidth/2-startsceneExitbtnImg:getWidth()/2 and love.mouse.getX() < windowWidth/2+startsceneExitbtnImg:getWidth()/2
	and love.mouse.getY() > 500+startsceneExitbtnImg:getHeight() and love.mouse.getY() < 500+startsceneExitbtnImg:getHeight()+startsceneExitbtnImg:getHeight() and love.mouse.isDown(1) then
		love.event.quit()
	end

	--love.graphics.draw(startsceneCreditsImg, windowWidth-startsceneCreditsImg:getWidth()*0.75, windowHeight-startsceneCreditsImg:getHeight()*0.75, nil, 0.75, 0.75)
end