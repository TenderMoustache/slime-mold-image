extensions[palette]

breed [nuclei nucleus]
breed [cytoplasm cytoplasmic-fluid]


cytoplasm-own [
  carrying-signal ; Used to modulate signal strength when particle is carrying food
  velocity ; The current velocity of the particle
]

patches-own [
  cp-fluid
  wall?
  food
]

to setup
  clear
  if setup-choice = "single-nucleus" [setup-single-nucleus]
  if setup-choice = "multi-nucleate" [setup-multi-nucleate]
  if setup-choice = "shortest-path" [setup-shortest-path shortest-path-parameters]
end


; These parameters are default because they offer a balance between performance and demonstrating the model's capabilities
to default-parameters
  set max-fluid-particles 10000
  set total-fluid-volume 50
  set diffusion-proportion 0.5
  set food-signal-boost 20
  set eat-proportion 0
  set signal-lifetime 50
  set fluid-turbulence 10
  set movement-speed 100
end


; These parameters differ to exaggerate the effect of food on the network,
; so that they may demonstrate the shortest-path finding ability in the shortest-path demo
to shortest-path-parameters
  set max-fluid-particles 3000
  set total-fluid-volume 25
  set diffusion-proportion 0.5
  set food-signal-boost 50
  set eat-proportion 0
  set signal-lifetime 100
  set fluid-turbulence 5
  set movement-speed 100
end


; resets the world state
to clear
  clear-all

  ; Initializing patch values
  ask patches [
    set wall? false
    set food 0
  ]

  reset-ticks
end



; A setup with a single nucleus in the middle; DEFAULT
to setup-single-nucleus
  create-nuclei 1 [
      set shape "circle"
      set size 5
      set color white
      setxy 0 0
    ]
  tick
end


; A slightly more elaborate setup that demonstrates the multi-nucleate
; nature of the network, as well as how it interacts with food
to setup-multi-nucleate
  create-nuclei 1 [
      set shape "circle"
      set size 5
      set color white
      setxy -30 0
    ]

  create-nuclei 1 [
      set shape "circle"
      set size 5
      set color white
      setxy 30 0
    ]

  draw-selection -5 -5 10 10 "food"

  tick
end



; A setup designed to demonstrate the ability of the network
; to find the shortest path length between food sources
to setup-shortest-path

  ; Creating the walled environment
  draw-box -50 -50 100 100 3
  draw-line -40 -17 80 57 "h"
  draw-line -38 -50 76 12 "h"

  draw-line -50 -50 20 12 "v"
  draw-line -40 -20 20 2 "v"

  draw-line 38 -50 20 12 "v"
  draw-line 38 -20 20 2 "v"

  draw-line -35 -26 70 2 "h"

  draw-line -35 -34 8 2 "v"
  draw-line -25 -34 8 2 "v"
  draw-line -15 -34 8 2 "v"
  draw-line 33 -34 8 2 "v"
  draw-line 23 -34 8 2 "v"
  draw-line 13 -34 8 2 "v"

  draw-line -30 -38 8 2 "v"
  draw-line -20 -38 8 2 "v"
  draw-line 28 -38 8 2 "v"
  draw-line 18 -38 8 2 "v"

  draw-line -14 -30 27 4 "h"
  draw-line -9 -38 19 4 "h"


  ; Placing food at path ends
  draw-selection -44 -26 6 2 "food"
  draw-selection 38 -26 6 2 "food"

  ; Placing a nucleus at the top
  create-nuclei 1 [
    set shape "circle"
    set size 5
    set color white
    setxy 0 43
  ]

end


to draw

  ; Handles the user draw function that allows for creation of
  ; the custom environment

  ; These should be drawn continuously
  if draw-choice = "Wall" [draw-wall]
  if draw-choice = "Food" [place-food]

  ; We only want one nucleus per click
  if draw-choice = "Nucleus" [
    let clicked? false
    while [mouse-down?] [
      if not clicked? [
        place-nucleus
        set clicked? true
      ]
    ]
  ]
end


;; ----- GO PROCEDURES -----



to go
  spawn-cytoplasm
  disperse-fluid
  move
  update-colors
  tick
end




to spawn-cytoplasm

  ; Handles spawning behavior for cytoplasmic fluid particles

  ; Variable initialization
  ; For each tick, calculate how many fluid agents remain unspawned
  let remaining max-fluid-particles - count cytoplasm
  let proportion 0.01  ; arbitrary value; how quickly fluid agents will spawn
  let spawn-count round(remaining * proportion)

  ; If the spawn-count is rounded to zero but remaining is greater than zero,
  ; we ensure that at least one particle will spawn
  if remaining > 0 [set spawn-count spawn-count + 1]

  ; Controls how cytoplasm fluid particles spawn relative to nuclei
  ask nuclei [
    if spawn-count > 0 [
      hatch-cytoplasm spawn-count [
        set velocity 1
        set carrying-signal 0
        rt random 360
        fd random 3
        hide-turtle
      ]
    ]
  ]
end


to disperse-fluid

  ; Controls the dispersion of fluid into the network

  ; Variable initialization
  ; Determine strength of signaling molecule from nutritive fluid
  ; Determine a rate of fluid decay for each patch based on the
  ; total allowable volume of fluid per agent
  let signal-boost food-signal-boost / 100
  let decay-rate (100 - total-fluid-volume) / 1000
  let max-cp max [cp-fluid] of patches
  if max-cp = 0 [set max-cp 0.1] ; avoids initial division by zero

  ; Nuclei need to emit fluid of their own to solidify their place in the network.
  ask nuclei [
    ask patches in-radius 3 [
      set cp-fluid 1
    ]
  ]

  ; Fluid particles need to distribute fluid. Value is modulated according
  ; to presence of signaling molecule (response to nutritive fluid)
  ask cytoplasm [
    if-else carrying-signal > 0 [
      set cp-fluid 1 + (signal-boost * (carrying-signal / signal-lifetime))
    ] [
      ; Rather than setting the patch fluid value to 1, we need to ensure that we only ever RAISE it to 1.
      ; This implementation ensures a non-food carrying fluid particle never sets the fluid concentration of a patch to a value
      ; LOWER than what it currently is. This also ensures that if two fluid particles occupy the same patch and only one is
      ; carrying a food signal, the patch will always receive the higher fluid concentration as is expected.
      if cp-fluid < 1 [set cp-fluid 1]
    ]
  ]

  ; Fluid spreads out over time. Altering this value will change how
  ; tightly the walls of each tube are defined.
  diffuse cp-fluid diffusion-proportion

  ; The cytoplasmic fluid that each agent represents needs to follow
  ; them over time, trails must decay over time.
  ask patches [
    if cp-fluid > decay-rate [

      ; The rate of fluid decay must be graded relative to the maximum fluid concentration in order
      ; to give network structures some staying power. This is an attempt, albeit a very basic one,
      ; to implement the cytoskeletal tube structures of real physarum polycephalum. Without this gradation
      ; in decay rate, network structures become wildly dynamic and quite sparse, as no structure that forms
      ; has anything 'holding' it in place. This is a weak mechanism that grants highly established network
      ; structures (those with the most fluid agents constantly occupying them) some permanence within the
      ; plasmodic network.
      set cp-fluid cp-fluid - (decay-rate * (1 - cp-fluid / max-cp))
    ]
  ]

  ; Remove any fluid that seeps into walls, or was present beforehand
  ask patches with [wall?] [
    set cp-fluid 0
  ]
end


to move

  ; Handles movement of the cytoplasmic fluid particles

  ; Cytoplasmic-fluid agent control flow
  ask cytoplasm [

    ; The following can occur if the user draws over existing agents with a wall
    if wall? = true [die]

    ; Eat if we can eat
    if food > 0 [eat]

    ; Propagate food signals to other fluid agents
    propagate-signal

    ; Fluid agents only 'look' ahead in the sense that fluid flows along
    ; tubes that have already formed, far less frequently straying to create
    ; new tubes. The likelihood of agents straying to create new tubes
    ; is dictated by the wobble value.
    let r patch-right-and-ahead 45 1
    let l patch-left-and-ahead 45 1
    let f patch-ahead 1

    ; Checking if the forward patch is a wall
    if-else ([wall?] of f) [
      ; We actively turn away from / avoid walls; mold can not grow there.
      ; This may be interpreted as the fluid 'bouncing' off of the wall upon impact
      rt 180
      wobble fluid-turbulence
    ]
    [
      ; In all other cases, we move in the direction of the tube
      ; (in this case, the direction in front of us with the highest fluid concentration)
      let xset (patch-set l r f)
      face max-one-of xset [cp-fluid]

      ; Random fluid turbulence
      wobble fluid-turbulence
    ]

    ; Fluid velocity is proportional to the strength / size of the tube.
    ; larger tubes are represented by higher fluid concentrations
    set velocity cp-fluid * (movement-speed / 100)
    fd velocity
  ]
end


to propagate-signal
  ; Agents that are carrying molecular signal must spread that signal to other agents
  if carrying-signal > 0 [

    ; The signal received by other turtles should be the maximum between what
    ; they currently have and what they are passing by. Turtles with higher signal
    ; values should not inherit lower ones
    let spread carrying-signal

    ask other cytoplasm-here [

      ; Transmission of the signal must also reduce its strength,
      ; as the molecule must travel some additional distance to reach the target of transmission.

      ; This does not violate conservation of matter; the fluid particle should not be conceived of as inheriting
      ; some quantity of matter, but rather something akin to being tagged by a trace chemical agent
      ; with a very specific lifetime / half life.
      set carrying-signal max (list carrying-signal (spread - 1))
    ]

    ; Signal lifetime must decrement once per tick.
    ; The molecular signal strength is inversely proportional its
    ; current distance travelled from its own point of origin (where the food is)
    set carrying-signal carrying-signal - 1
  ]
end


to eat

  ; This functions controls the eating behavior of fluid agents

  ; Remove food from the patch
  set food food - eat-proportion

  ; Fluid is now carrying the molecular signal
  set carrying-signal signal-lifetime
end



to wobble [x]
  ; This function controls the random movements of the fluid agents
  rt random x
  lt random x
end




to update-colors

  ; Mold networks can be visualized 'realistically' or
  ; proportional to the local velocities.

  if-else visualize-velocity? [

  ; real-time visualization of the varying velocities of
  ; cytoplasmic fluid particles within the network. Color is representative
  ; of the maximal fluid particle velocity for a given patch

    if any? cytoplasm [
      let highest max [velocity] of cytoplasm
      ask patches [
        let x max-one-of cytoplasm-here [velocity]
        if-else x != nobody [
          let v ([velocity] of x) / highest
          set pcolor palette:scale-gradient [[0 255 25] [255 255 0] [255 0 0]] v 0.7 1
        ]
        [
          set pcolor black
        ]
      ]
    ]
  ]


  ; 'realistic' representation of the slime-mold
  [
    ask patches
    [
      let signal-boost food-signal-boost / 100
      if-else cp-fluid <= 1 [
        ; Gradient represents the strength of the tube / fluid concentration
        set pcolor palette:scale-gradient [[0 0 0] [255 255 255]] cp-fluid 0 1
      ]
      [
        ; Identify fluid carrying the signaling molecule
        if-else visualize-signaling-molecule?
        [set pcolor yellow]
        [set pcolor white]
      ]
    ]
  ]

  ; In either visualization case, we want to render both food
  ; and walls individually.
  ask patches [
    if food > 0 [set pcolor yellow]
    if wall? = true [set pcolor red]
  ]
end

to draw-wall

  ; This function allows the user to draw walls
  ; that the mold will be forced to avoid

  while [mouse-down?] [
    ask patch mouse-xcor mouse-ycor [
      ask patches in-radius brush-size [
        if-else eraser
        [set wall? false]
        [set wall? true]
      ]
    ]
    update-colors
    tick
  ]
end

to place-nucleus

  ; This allows the user to place mold nuclei. P. Polycephalum are
  ; multi-nucleate organisms, so multiple nuclei can exist simultaneously

  if mouse-down? [
    create-nuclei 1 [
      set shape "circle"
      set size 5
      set color white
      setxy mouse-xcor mouse-ycor
    ]
    tick
  ]
end

to place-food

  ; Allows the user to place nutritive fluid that stimulates the
  ; mold network, acting as a source of the signaling molecule that
  ; the mold will respond to.

  while [mouse-down?] [
    ask patch mouse-xcor mouse-ycor [
      ask patches in-radius brush-size [
        if-else eraser
        [set food 0]
        [set food 1]
      ]
    ]
    update-colors
    tick
  ]
end




;; ----- PROCEDURES FOR DRAWING WALLS -----

; draws a box wall formation
to draw-box [x y width height thick]

  ; horizontal components
  draw-line x y width thick "h"
  draw-line x (y + height - thick) width thick "h"

  ; vertical components
  draw-line x y height thick "v"
  draw-line (x + width - thick) y height thick "v"


end


; given an orientation "h" or "v" draws a line
to draw-line [x y len thick orientation]
  if orientation = "v" [
    draw-vertical-line x y len thick
    stop
  ]

  if orientation = "h" [
    draw-horizontal-line x y len thick
    stop
  ]

end


; draws a horizontal line
to draw-horizontal-line [x y len thick]
  draw-selection x y len thick "wall"
end

; draws a vertical line
to draw-vertical-line [x y len thick]
  draw-selection x y thick len "wall"
end


; fills a rectangular patch selection with either wall or food
to draw-selection [x y width height wall-or-food]

  let selected (select-rectangle x y width height)

  if-else wall-or-food = "food"
  [foreach selected [p -> ask p [set food 1]]]
  [foreach selected [p -> ask p [set wall? true]]]

  update-colors
  tick

end


; Given a starting coordinate and dimensions, returns a patch-set corresponding to that area
; ** Coordinate starts at bottom left of the selection **
to-report select-rectangle [x y width height]

  ; Initialization
  let selected []
  let x-counter 0
  let y-counter 0

  ; Double loop to grab all values in a rectangular area
  while [x-counter < width] [
    set y-counter 0
    while [y-counter < height] [
      set selected lput (patch (x + x-counter) (y + y-counter)) selected
      set y-counter y-counter + 1
    ]
    set x-counter x-counter + 1
  ]

  report selected

end
