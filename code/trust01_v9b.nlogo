;;code by anonymised @2013
;;modified by anonymised @2015


turtles-own
[
  p?
  r?
  _p?
  _r?
  s?
  _s?
  skeptic?
  lazy?
  costs
  ranking
]

links-own
[
  trust
]

globals
[
 moviePath
 discoverP
 discoverNotP
]

to partial_setup
  ifelse (count turtles = 0)
  [
    setup
  ]
  [
   clearP
  ]
end

to setup
  clear-all
  set moviePath ""
  set discoverP -1
  set discoverNotP -1
  set-default-shape turtles "circle"
  if (_network_type = "total")
  [
     create-turtles _nodes
     [
      initializeTurtle
      set ranking 0
     ]
     ask turtles [ create-links-with other turtles ]
     layout-circle turtles 13
  ]
  if (_network_type = "linear")
  [
    let maxTurtles _nodes
    let counter 0
    if (world-height * world-width < maxTurtles) [ set maxTurtles world-height * world-width ]
    let newX 0
    let newY world-height - 1
    create-turtles maxTurtles
    [
      initializeTurtle
      set ranking counter
      setxy newX newY
      set newX newX + 1
      if (newX = world-width)
      [
        set newX 0
        set newY newY - 1
      ]
      set counter counter + 1
    ]
    ask turtles
    [
      let r ranking
      create-links-with turtles with [ ranking = r + 1 ]
    ]
  ]


if (_network_type = "random")
  [
    create-turtles _nodes [ initializeTurtle ]
    ;;draw network
    let total-edges round (count turtles)
    while [count turtles < total-edges]
    [
      ask one-of turtles
      [
        ask one-of other turtles [ create-link-with myself ]
      ]
    ]
    ;;ensure that there are no completely isolated checkpoints
    ask turtles with [count link-neighbors = 0]  [ create-link-with one-of other turtles ]
    layout-radial turtles links max-one-of turtles [count link-neighbors]
  ]
  ;;create a small-world network using preferential attachment dynamics
  if (_network_type = "small-world")
  [
    create-turtles 3 [ initializeTurtle ]
    ask turtle 0 [ create-link-with one-of other turtles ]
    ask one-of turtles with [count link-neighbors = 0] [ create-link-with one-of other turtles ]
    ;;add new node using albert-barabasi method
    while [count turtles < (_nodes + 1)]
    [
       create-turtles 1
       [
         initializeTurtle
         create-link-with find-partner
       ]
    ]
    ask turtles [ set ranking 1 / count link-neighbors ]
    layout-radial turtles links max-one-of turtles [count link-neighbors]
  ]
  if (_network_type != "total" and _network_type != "linear")
  [
    let factor 1.5 / ((max [count link-neighbors] of turtles) - (min [count link-neighbors] of turtles))
    ask turtles [ set size 0.5 + (count link-neighbors * factor) ]
  ]
  ask links [ set trust 0 ]
  graph-edges
  reset-ticks
end

to clearP
  ask turtles
  [
    set color blue
    set p? false
    set _p? false
    set r? -2
    set _r? -2
    set costs 0
  ]
  set-current-plot "knowledge"
  clear-plot
  reset-ticks
end

to initializeTurtle
  setxy random-pxcor random-pycor
  set color blue
  set size 0.8
  set p? false
  set _p? false
  set r? -2
  set _r? -2
  set costs 0
  set ranking who
  set s? -2
  set _s? -2
  set skeptic? false
  if (random-float 1 <= proportionSkeptic / 100)
  [
    set shape "triangle"
    set skeptic? true
  ]
end

to-report find-partner
  let total random-float sum [count link-neighbors] of turtles
  let partner nobody
  let q 0
  while [q < count turtles]
  [
    ask turtle q
    [
      let nc count link-neighbors
      ;; if there's no winner yet...
      if partner = nobody
      [
        ifelse nc > total [ set partner self ]
        [ set total total - nc ]
      ]
    ]
    set q q + 1
  ]
  report partner
end

to go
  if (_exportMovie and ticks = 0) [ start-movie ]
  ifelse count (turtles with [ not p? and not _p? ]) > 0
  [
    ask turtles with [ p? ]
    [
      if (count (link-neighbors with [ not p? ]) > 0)
      [
        let r ranking
        let s who
        ask one-of link-neighbors with [ not p? ] [ knowP r false s -2 ]
      ]
    ]
    ask turtles with [ _p? ]
    [
      if (count (link-neighbors with [ not _p? ]) > 0)
      [
        let r ranking
        let s who
        ask one-of link-neighbors with [ not _p? ] [ know_P r false -2 s ]
      ]
    ]
    ask turtles with [ _p? and p? ] [ solveConflicts ]
    tick
    draw-knowledgeable
    if (_exportMovie and moviePath != "") [ movie-grab-view ]
  ]
  [
    if (_log) [ export-data ]
    if (_exportMovie and moviePath != "") [ end-movie ]
    stop
  ]
end

to solveConflicts
  let totalP count turtles with [ p? and not _p? ]
  let total_P count turtles with [ _p? and not p? ]
  ;;choose P or notP based on the ranking and the number of agents already believing the proposition
  let scoreP 1 / r? + (totalP / count turtles)
  let score_P 1 / _r? + (total_P / count turtles)
  if (s? > -1 and _s? > -1)
  [
    let t1 [ trust ] of link-with turtle s?
    let t2 [ trust ] of link-with turtle _s?
    if (t1 > t2)
    [
      set scoreP 1
      set score_P 0
    ]
    if (t2 > t1)
    [
      set scoreP 0
      set score_P 1
    ]
  ]
  if (scoreP > score_P) ;;P
  [
    set _p? false
    knowP r? false -1 -1
  ]
  if (scoreP < score_P) ;;notP
  [
    set p? false
    know_P _r? false -1 -1
  ]
  if (scoreP = score_P) ;;randomly break ties
  [
    ifelse (random-float 1 >= 0.5)
    [
      set _p? false
      knowP r? false -1 -1
    ]
    [
      set p? false
      know_P _r? false -1 -1
    ]
  ]
end

to discovery
  ask one-of turtles [ knowP -1 true -1 -1 ]
end

to contradictory-discovery
  if (discovery_type = "random")
  [
    ask one-of turtles [ knowP -1 true -1 -1 ]
    ask one-of turtles with [p? = false] [ know_P -1 true -1 -1 ]
  ]
  if (discovery_type = "lazyP-skepticNotP")
  [
    ask one-of turtles with [skeptic? = false] [ knowP -1 true -1 -1 ]
    ask one-of turtles with [p? = false and skeptic? = true] [ know_P -1 true -1 -1 ]
  ]
  if (discovery_type = "lazyNotP-skepticP")
  [
    ask one-of turtles with [skeptic? = true] [ knowP -1 true -1 -1 ]
    ask one-of turtles with [p? = false and skeptic? = false] [ know_P -1 true -1 -1 ]
  ]
  if (discovery_type = "lazyP-lazyNotP")
  [
    ask one-of turtles with [skeptic? = false] [ knowP -1 true -1 -1 ]
    ask one-of turtles with [p? = false and skeptic? = false] [ know_P -1 true -1 -1 ]
  ]
  if (discovery_type = "skepticP-skepticNotP")
  [
    ask one-of turtles with [skeptic? = true] [ knowP -1 true -1 -1 ]
    ask one-of turtles with [p? = false and skeptic? = true] [ know_P -1 true -1 -1 ]
  ]
end

to knowP [ otherRanking certainty s1 s2 ]
  ;;if the turtle sending information is LESS important than me, check info
  ;;if (otherRanking > ranking) [ set costs costs + 1 ]
  if (s1 >= 0) [ set s? s1 ]
  let verification true
  if (certainty = false) [ set verification verify s? ]
  ifelse (verification)
  [
    set p? true
    set r? otherRanking
    if (otherRanking = -1) [ set discoverP who ]
    set color magenta
  ]
  [ know_P otherRanking true -1 -1 ]
end

to know_P [ otherRanking certainty s1 s2 ]
  ;;if the turtle sending information is LESS important than me, check info
  ;;if (otherRanking > ranking) [ set costs costs + 1 ]
  if (s2 >= 0) [ set _s? s2 ]
  let verification true
  if (certainty = false) [ set verification verify _s?  ]
  ifelse (verification)
  [
    set _p? true
    set _r? otherRanking
    if (otherRanking = -1) [ set discoverNotP who ]
    set color green
  ]
  [ knowP otherRanking true -1 -1 ]
end

to-report verify [ source ]
  ;;IF SKEPTIC, VERIFY
  ifelse (skeptic?)
  [
    set costs costs + 1
    let confirm false
    if (random-float 1 <= confirmationSkeptic) [ set confirm true ]
    assignTrust confirm source
    report confirm
  ]
  ;;ELSE, verified by default
  [ report true ]
end

to assignTrust [ verified agent ]
  let currentLink link-with turtle agent
  ifelse (verified)
  [
    ask currentLink
    [
      set trust 1
      set color green
    ]
  ]
  [
    ask currentLink
    [
      set trust -1
      set color red
    ]
  ]
end

to draw-knowledgeable
  set-current-plot "knowledge"
  let perc-knowledgeable ((100 * (count turtles with [ p? ])) / (count turtles))
  plot perc-knowledgeable
end

to graph-edges
  set-current-plot "edge-distribution"
  set-plot-x-range 1  1 + max [count link-neighbors] of turtles
  histogram  [count link-neighbors] of turtles
end

;;Export data in tables for analysis.
to export-data
  ;;The current time is used to generate the series of tables of a model run.
  let _filename date-and-time
  ;;Format the name in order not to have problem with windows constraints.
  set _filename remove ":" _filename
  set _filename remove "." _filename
  set _filename word _filename ".txt"
  ;;Open the file
  file-open _filename
  ;;Header containing model parameters
  let _temp "model parameters"
  file-print _temp
  set _temp "nodes"
  set _temp word _temp "\t"
  set _temp word _temp _nodes
  file-print _temp
  set _temp "skeptics"
  set _temp word _temp "\t"
  set _temp word _temp count turtles with [skeptic? = true]
  file-print _temp
  set _temp "% of confirmation for skeptics' control"
  set _temp word _temp "\t"
  set _temp word _temp confirmationSkeptic
  file-print _temp
  set _temp "network type"
  set _temp word _temp "\t"
  set _temp word _temp _network_type
  file-print _temp
  set _temp "discovery_type"
  set _temp word _temp "\t"
  set _temp word _temp discovery_type
  file-print _temp
  ;;Empty line
  file-print ""
  ;;Data
  file-print "model output"
  set _temp "total costs"
  set _temp word _temp "\t"
  set _temp word _temp sum [costs] of turtles
  file-print _temp
  set _temp "total timesteps"
  set _temp word _temp "\t"
  set _temp word _temp ticks
  file-print _temp
  set _temp "turtle that knows p"
  set _temp word _temp "\t"
  set _temp word _temp count turtles with [ p? ]
  file-print _temp
  set _temp "turtle that knows not p"
  set _temp word _temp "\t"
  set _temp word _temp count turtles with [ _p? ]
  file-print _temp
  if (discoverP > -1)
  [
    set _temp "turtle that discovers p (id,ranking,skeptic?)"
    set _temp word _temp "\t"
    set _temp word _temp discoverP
    set _temp word _temp "\t"
    set _temp word _temp [ranking] of turtle discoverP
    set _temp word _temp "\t"
    set _temp word _temp [skeptic?] of turtle discoverP
    file-print _temp
  ]
  if (discoverNotP > -1)
  [
    set _temp "turtle that discovers not p (id,ranking,skeptic?)"
    set _temp word _temp "\t"
    set _temp word _temp discoverNotP
    set _temp word _temp "\t"
    set _temp word _temp [ranking] of turtle discoverNotP
    set _temp word _temp "\t"
    set _temp word _temp [skeptic?] of turtle discoverNotP
    file-print _temp
  ]
  file-close
end

to start-movie
  ;;Prompt user for movie location.
  user-message "First, save your new movie file (choose a name ending with .mov)"
  let path user-new-file
  ifelse not is-string? path [ stop ]  ;;Stop if user canceled
  [
    set moviePath path
    movie-start path
  ]
end

to end-movie
  movie-close
  user-message (word "Exported movie to " moviePath)
end
@#$#@#$#@
GRAPHICS-WINDOW
258
10
578
361
-1
-1
10.0
1
10
1
1
1
0
0
0
1
0
30
0
31
0
0
1
ticks
30.0

BUTTON
18
12
81
45
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
98
13
236
58
_network_type
_network_type
"total" "random" "small-world" "linear"
1

SLIDER
17
81
126
114
_nodes
_nodes
10
300
100
10
1
NIL
HORIZONTAL

PLOT
606
12
766
132
edge-distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
787
12
844
57
edges
count links
17
1
11

BUTTON
103
138
203
171
go-forever
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
605
150
766
284
knowledge
time-step
perc. infected
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -5825686 true "" ""

BUTTON
258
373
350
406
NIL
discovery
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
137
79
170
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
789
75
866
120
totalCosts
sum [costs] of turtles
17
1
11

BUTTON
366
373
548
406
NIL
contradictory-discovery
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
17
246
189
279
proportionSkeptic
proportionSkeptic
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
16
295
193
328
confirmationSkeptic
confirmationSkeptic
0
100
95
1
1
NIL
HORIZONTAL

BUTTON
17
186
86
219
NIL
clearP
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
790
139
871
184
lazyTurtles
count turtles with [skeptic? = false]
17
1
11

MONITOR
793
200
894
245
skepticTurtles
count turtles with [skeptic? = true]
17
1
11

MONITOR
867
11
960
56
NIL
count turtles
17
1
11

SWITCH
138
81
241
114
_log
_log
0
1
-1000

SWITCH
18
375
159
408
_exportMovie
_exportMovie
1
1
-1000

CHOOSER
572
365
751
410
discovery_type
discovery_type
"random" "lazyP-skepticNotP" "lazyNotP-skepticP" "lazyP-lazyNotP" "skepticP-skepticNotP"
1

BUTTON
103
187
229
220
NIL
partial_setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment10linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment60sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment40skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment50skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300skeptic" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment40lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment50lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300lazy" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment40random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment50random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment10linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment40linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment50linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment10total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment40linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment50linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment20total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment30total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment40total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment50total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment70sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment80sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment90sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment110sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="110"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment120sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment130sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="130"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment150sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment160sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment170sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment180sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment190sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="190"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment210sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="210"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment220sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="220"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment230sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="230"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment240sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment250sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment260sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="260"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment270sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="270"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment280sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="280"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment290sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="290"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300sw" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;small-world&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment60linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment70linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment80linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment90linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment110linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="110"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment120linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment130linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="130"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment140linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment150linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment160linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment170linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment180linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment190linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="190"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment210linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="210"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment220linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="220"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment230linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="230"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment240linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment250linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment260linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="260"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment270linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="270"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment280linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="280"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment290linear" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="290"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment70random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment80random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment90random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment110random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="110"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment120random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment130random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="130"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment140random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment150random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment160random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment170random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment180random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment190random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="190"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment210random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="210"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment220random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="220"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment230random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="230"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment240random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment250random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment260random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="260"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment270random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="270"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment280random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="280"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment290random" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="290"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment60total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment70total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment80total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment90total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment100total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment110total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="110"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment120total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment130total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="130"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment140total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment150total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment160total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment170total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment180total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment190total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="190"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment200total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment210total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="210"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment220total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="220"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment250total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment300total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment260total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment260total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="260"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment270total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="270"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment280total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="280"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment290total" repetitions="30" runMetricsEveryStep="false">
    <setup>partial_setup
contradictory-discovery</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>sum [costs] of turtles</metric>
    <metric>count turtles with [ p? ]</metric>
    <metric>count turtles with [ _p? ]</metric>
    <metric>[ranking] of turtle discoverP</metric>
    <metric>[ranking] of turtle discoverNotP</metric>
    <enumeratedValueSet variable="_log">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="discovery_type">
      <value value="&quot;lazyP-skepticNotP&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_exportMovie">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportionSkeptic">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_network_type">
      <value value="&quot;total&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="_nodes">
      <value value="290"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmationSkeptic">
      <value value="95"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
