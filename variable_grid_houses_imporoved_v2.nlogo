breed [ houses house ]
breed [ owners owner ]
breed [ negotiations negotiation ]
breed [ offers offer ]

globals
[
  grid-size           ;; the amount of patches in between two roads in the x direction
  year
  month
  year-duration
  roads         ;; agentset containing the patches that are roads
  parcels
  percentage    ;;list that keeps track of the percentage that the selling price is of the initial sale price
  amount-negotiations ;;list that keeps track of the percentage that the selling price is of the initial sale price
  total-moves
  test-person-succes
  total-negotiation
]

houses-own
[
  my-owner            ; the owner who lives in this house
  for-sale?           ; whether this house is currently for sale
  sale-price          ; the price of this house (either now, or when last sold)
  offered-to          ; which owner has already made an offer for this house
  my-negotiation      ; the current negotiation that is going on
  ticks-since-last-buy
]

;;occupied or not?
patches-own
[
  hasHouse?
]

owners-own
[
  my-house
  income
  loan
  repayment
  capital
  wants-to-buy
  price-offered
  has-switched?
]

negotiations-own
[
 trade-house
 price-asked
 buyers
 seller
 initial-sale-price
 start-date
]

to setup
  clear-all
  reset-ticks

  ;;setup the global variable and construct the city
  setup-globals
  setup-patches

  ;;fill the city with houses
  repeat (count (parcels) * initial-occupation / 100 ) [ build-house ]

  ;assign prices to the houses
  set-initial-price

  ;;create an certain amount of houses and hatch owners that inhabit them
  ask houses [ set for-sale? true ]
  set-default-shape owners "dot"
  let occupied-houses n-of  ((initial-house-occupation / 100 ) * count houses) houses
  ask occupied-houses [
    set for-sale? false
    hatch-owners 1 [
    set color white
    set shape "dot"
    set my-house myself
      ask my-house [
      set my-owner myself
      set color green
      ]
      set-initial-loan-and-repayment my-house
      set-initial-capital
    ]
  ]

  ;;create owners that are looking to move into this city and currently don't have a house
  create-owners round(count owners / 10)[
    set my-house nobody
    set-initial-capital
    set color white
    hide-turtle
  ]
  reset-ticks
end

;; Initialize the global variables to appropriate values
to setup-globals
  set percentage [] ;;empty list
  set amount-negotiations [] ;;empty list
  set month 1 ;;start in first month
  set year 1;;
  set loan-duration loan-duration
  set year-duration 26 ;;ticks, one tick is two weeks
  set grid-size world-width / gridslider
  set grid-size world-height / gridslider
end

to build-house     ;; observer procedure
;; add a single house to the town, in a random location
  create-houses 1 [
    set color blue
    set shape "house"
    let empty one-of parcels with [ not any? houses-here ]
    move-to empty
    ask empty [set hasHouse? 1
     set pcolor red
    ]
    ;;initialize an empty list for the owners that want to buy this specific house
    set offered-to []
    ]
end

to set-initial-price ;;house procedure
  ask houses [
    set sale-price random-normal 266000 43000 ;;parameters mean house price and z-value
    let location-correction (4 - (floor(sqrt(abs(xcor) + abs(ycor)))) ) * 20000 ;;houses closer to the city center are more expensive
    let boost ifelse-value (random 10 = 0) [random-gamma 1.3 (1 / 30000)] [0] ;;some houses just are more expensive because they're exclusive
    set sale-price sale-price + location-correction + boost
  ]
end

to set-initial-capital ;;owners procedure
  while [income < mean-income * 0.25] [ ;;is a quarter of the mean income in the netherlands
  set income random-gamma 1.3 (1 / 16000) ;;NOTE TO SELF: parameters taken from paper ;;reference it!
  ]
  ifelse  (income / mean-income) > 1 [
    ;;generate some savings that can be put into a house as a deposit
    set capital mean-savings + ((1 + random 3) * 10000)
  ]
  [
    set capital max list 0 mean-savings - ((1 + random 3) * 10000)
  ]
end

to set-initial-loan-and-repayment [house-for-loan];;owner procedure
  let one-fifth ([sale-price] of house-for-loan)
  ifelse one-fifth > (2 * capital)
  [
  set loan ([sale-price] of house-for-loan * (4 / 5))
  ]
  [
  set loan [sale-price] of house-for-loan
  ]
  set repayment calculate-monthly-repayment self
end


to paint-houses
  ask houses [
  ifelse is-negotiation? my-negotiation
  [
    set color orange
  ]
  [
    ifelse for-sale? [
    set color blue
    ]
    [
      ifelse is-owner? my-owner [
        set color green
      ]
      [
        set color white ;;for debugging purposes, should not be visible for more than 1 cycle as houses without an owner should be for sale.
      ]
    ]
   ]
  ]
end

to setup-patches ;; observer procecure
  set-patch-size 15
  ;;Define the city (relative to its size) with roads and parcels where houses can be build upon
  set roads patches with
  [
    (floor((pxcor  + max-pxcor - floor(grid-size)) mod grid-size) = 0) or   ;;( these are grid-size) vertical lines
    (floor((pycor  + max-pycor) mod grid-size) = 0) or
    (pxcor = max-pxcor) or (pycor = max-pycor)
  ]

  set parcels patches with
  [
    not(
    (floor((pxcor  + max-pxcor - floor(grid-size)) mod grid-size) = 0) or   ;;( these are grid-size) vertical lines
    (floor((pycor  + max-pycor) mod grid-size) = 0)   or
    (pxcor = max-pxcor) or (pycor = max-pycor) )
  ]

  ask roads [ set pcolor white ]
  ask parcels [ set pcolor black ]
end


;; Run the simulation
to go
  ;;Set unoccupied houses for sale by default
  ask houses with [not is-owner? my-owner and not for-sale?][set for-sale? true]

  let owners-with-house owners with [ is-house? my-house and not [for-sale?] of my-house ]
  ;;a small amount of people enter or leave city arbitrarily, only do this once per two year to keep it realistic
  if (month mod 24 = 0) [
  if moving-in-and-out-city [
    if any? owners-with-house with [wants-to-buy = [] ] [
      ;;people that leave the city
    let random-movers n-of round((city-entry-and-leave-rate / 100 ) * count owners-with-house) owners-with-house with [wants-to-buy = [] ]
    ;  (round(random count owners-with-house / 150) ) owners-with-house
    if any? random-movers
    [
      ask random-movers [
        ask my-house[
          set for-sale? true
        ]
        die
      ]
    ]
    ]
     ;;new owners
    create-owners round((city-entry-and-leave-rate / 100 ) * count owners-with-house) [
    set my-house nobody
    set-initial-capital
    set color white
    hide-turtle
  ]
  ]
  ]

  let want-to-buy owners-with-house with [not (repayment = 0) and (income / 12) / repayment > 4] ;;have financial means to move up
  set want-to-buy n-of floor(count want-to-buy /  10) want-to-buy
  if any? want-to-buy
  [
    ask want-to-buy [
      ask my-house[
        set for-sale? true
      ]
    ]
  ]
  let want-to-sell owners-with-house with [not (repayment = 0) and repayment / (income / 12 ) < 0.7] ;;don't have financial means to live in this house, move down
  set want-to-sell n-of floor(count want-to-sell /  10) want-to-sell
  if  any? want-to-sell
  [
    ask want-to-sell [
      ask my-house[
        set for-sale? true
      ]
    ]
  ]

  tick ;; to model the two week per tick a tick is placed here

  ;;select available houses of which the competition is not already saturated
  let houses-for-sale houses with [ for-sale? and length offered-to < max-competitors-for-one-house ]

  ;;owners without a house get express their interest in a new house first
  ask owners with [ not(is-house? my-house) ] [
    save-interesting-houses houses-for-sale
   ]

  ;;check agian for the houses with saturated competition
  set houses-for-sale houses with [for-sale? and length offered-to < max-amount-negotiations ]

  ;;subsequently, owners that want to move but still have a house in possesion get to express their interest
  ask owners with [ (is-house? my-house) and ([ for-sale? ] of my-house) and not (is-house? wants-to-buy) ] [
    save-interesting-houses houses-for-sale
   ]

  ;;carry out the negotiations
  if (count negotiations > 0)
  [
    ask negotiations
    [
      negotiate
    ]
  ]

  ;;display things
  paint-houses
  plot-statistics

  ;;only display turtles that live in a house
  ask owners [show-hide-owners]

;  ask houses [set ticks-since-last-buy ticks-since-last-buy + 2]
;  set succes-rate (total-moves / test-person-succes ) / 0.01
  tick
  ;;increment months and year for monitoring purposes
  if (ticks mod 24 = 0) [set year year + 1]
  set month ifelse-value (month = 12) [1] [ month + 1 ]
end


to negotiate ;;procedure for the negotiations turtle set, try to reach an agreement
  let duration (ticks - start-date)
  let testperson one-of turtle-set buyers
  let overbidding buyer-strategy = "overbidding"
  let isp initial-sale-price
  let underbidding buyer-strategy = "underbidding"
  ;;first, buyers that are competing in this negotiation and did not make an initial offer should make one first.
  let newcomers turtle-set buyers
  ask newcomers with [price-offered = 0]
  [
    ;;generate sale prices based on a normal distribution with mean initial sale price and sd a variable part of the sale price
    ;;if the buyer is the expirimental one, adjust offers accordingly
    ifelse (self = testperson) [
        if overbidding [
           set price-offered isp + abs(isp - random-normal isp (isp / (4 + random 10)))
        ]
        if underbidding [
          set price-offered isp - abs(isp - random-normal isp (isp / (4 + random 10)))
        ]
    ]
    [
      set price-offered random-normal  isp (isp / (4 + random 10)) ;;make initial bid
    ]
  ]
  ;for the first negotiation cycle initial offering and asking prices are established
  ifelse (price-asked = 0)
  [
    ifelse is-owner? seller
    [ ;;if the house has an current owner, let them determine asking price. Since it concerns a bidding war, let the sale price be above value of the house

      set price-asked initial-sale-price + abs(initial-sale-price - random-normal initial-sale-price (initial-sale-price / (4 + random 10)))
    ]
      ;;if not an owner just take the sale price as a starting point in the  negotiation
    [
      set price-asked [sale-price] of trade-house ;;otherwise just take the initial sale price as a starting point
    ]
  ]
  ;;otherwise start another negotiation cycle in which buyer ad seller try to reach an agreement.
  [
    ;;first check if the negotiation does not go too long, multiplied by two because every
    ;;negotiation occurs per two cycles
    if (duration >= max-amount-negotiations * 2 )
    [
      ;;undo the offering of this house to the owner
      ask trade-house
      [
      ask turtle-set offered-to [
         set wants-to-buy 0
         set price-offered 0
        ]
      ]
      ;;the house can go back on the market
      ;;keep the for-sale flag but set the offered to and negotiation parameters to zero.
      ask trade-house
      [
        set offered-to []
        ;;the user has to be cut out of this list
        set my-negotiation nobody
        set for-sale? false
      ]
      ;;cancel this negotiation because an agreement wasn't reached
      ask self [
        die
      ]
    ]
    ;;Set the prices as a result of the amount of negotations. More cycles contribute to adjusting to each other.
  ]

  ;;do another bidding cycle, one of the potential buyers either overbids or underbids while others increase towards their price.
  let num-competitors length buyers
;  print num-competitors
  ask turtle-set buyers[
    let gap [price-asked] of myself - price-offered
;    print gap
  ]

  ;;check for a possible purchase
;  print self
;  print possible-purchase? self
  if possible-purchase? self ;;at least the price-asked can be reached
  [
    ;;In most cases the winner is the one with the highest bidding price
    ;;but sometimes the buyer does not get to assemble all the bids or does not choose the highest
    ;;therefore some randomization is introduced in this model
    let winner ifelse-value (random 10  = 0) [one-of turtle-set buyers] [max-one-of turtle-set buyers [price-offered] ]
    if (winner = testperson)
    [
      set test-person-succes test-person-succes + 1
    ]
    ;;append to the list to be able to plot the mean percentage of the asking price
    let this-price [price-offered] of winner  ;;either max or random because seller might not be able to assemble al bids

    let percentage-to-append 100 * this-price / initial-sale-price

    if (percentage-to-append > 0)
    [
      set percentage lput percentage-to-append percentage
    ]
    ;;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    let previous-owner [my-owner] of trade-house
    let my-old-house [my-house] of winner
    let my-new-house trade-house
    ;;Move out of the old house and put it on the market
    if (is-house? my-old-house)
    [
      ask my-old-house [
        set my-owner nobody
        set for-sale? true ;;because they left old house
      ]
    ]
    ;;the old inhabitant does not live in this house anymore
    if (is-owner? previous-owner) [
      ask previous-owner
      [
        set my-house nobody
      ]
    ]
    ;;tell the new house that is has a new owner
    ask my-new-house
    [
      set my-owner winner
      set for-sale? false ;;this house has just been bought
      set offered-to [] ;;other competitors have failed
    ]
    ;;let the new buyer move into his new house
    ask winner
    [
      set my-house my-new-house ;;move into new one
      move-to my-house ;;display it right
      set price-offered 0 ;;bid has been accepted
      set wants-to-buy 0
    ]

    set total-moves total-moves + 1
    ask self [ die ]
   ]
end

;;auxilary function that reports whether or not the price difference between asked and offered amount is below the threshold value
to-report possible-purchase? [this-negotiation]
;  let competitors turtle-set buyers
  let max-price-offerd max [price-offered] of turtle-set buyers
  ifelse ([price-asked] of this-negotiation - max-price-offerd) <= price-gap [report true][report false]
end

;;only display the owners as white dots if they own a house
to show-hide-owners
  ifelse is-house? my-house
  [
    show-turtle
  ]
  [
    hide-turtle
  ]
end

to save-interesting-houses [available-houses] ;;owner procedure

  let capital-surplus ifelse-value (capital > 15000) [capital - 15000] [0] ;;part of the captial needs to be saved for expenses according to nibud -> NOTE TO SELF: SOURCE IN REPORT
  let budget ifelse-value (is-house? my-house) [capital-surplus + [sale-price] of my-house] [capital-surplus]

  let upperlimit budget * buyers-upper-limit
  let lowerlimit budget * buyers-lower-limit

  let current-house my-house
  let interesting-houses available-houses with
  [
   self != current-house and
   for-sale? and
   sale-price <= upperlimit and
   sale-price >= lowerlimit
  ]

  ;;this is a safety line since the filters above still yields that an owner wants to buy it's own house
  ;;set interesting-houses interesting-houses with [not member? self interesting-houses]

  if count interesting-houses > max-amount-houses
  [
    set interesting-houses n-of max-amount-houses interesting-houses
  ]

  ;;see if any houses fit the critera
  if any? interesting-houses
  [
    let potential-new-house one-of interesting-houses with [length offered-to < max-competitors-for-one-house]
    if (is-house? potential-new-house and not (potential-new-house = my-house))
    [
      ask potential-new-house
      [
        set offered-to lput myself offered-to ;;append this owner to the list of owners that want to buy this house
      ]
      set wants-to-buy potential-new-house ;;express interest and start possible negotation
      let isp [sale-price] of potential-new-house

      ;;If a negotiation does not currently exist, create initiate a new one
      ifelse not(is-negotiation? [my-negotiation] of potential-new-house)
      [
        hatch-negotiations 1
        [
          ;;altough it's gonna be invisible move it to the correct patch
          move-to potential-new-house
          hide-turtle
          set trade-house potential-new-house
          let this-buyer myself
          set buyers lput myself []
          set seller [my-owner] of potential-new-house
          set initial-sale-price isp
          set start-date ticks
          ask potential-new-house
          [
            set my-negotiation myself
          ]
        ]
      ]
      ;;Else if a negotiation already exists, welcome the owner to compete for their possible future house
      [
        ask [my-negotiation] of potential-new-house [
          set buyers lput myself buyers
        ]
      ]
    ]
  ]

end

;;based on 2 percent interest rate, formula taken from wikipedia, TODO search for original source.
to-report calculate-monthly-repayment [ owner-with-mortgage ]
  report ((2 / 100 / 12) * [loan] of owner-with-mortgage ) / ( 1 - ((1 + 2 / 100 / 12)) ^ (- loan-duration * 12))
end

to plot-statistics
  ;;house price distribution plot
  let houses-for-sale houses with [ for-sale?  and sale-price > 0 ]
  set-current-plot "House price distribution"
  set-plot-pen-interval 10000
  set-plot-x-range floor([sale-price] of min-one-of houses [sale-price]) ceiling([sale-price] of max-one-of houses [sale-price])
  set-current-plot-pen "For sale"
  histogram [ sale-price ] of houses-for-sale

  ;;amount of negotiations in a specific cycle plot
  set amount-negotiations lput count negotiations amount-negotiations
  if length amount-negotiations > display-last-x-cycles [set amount-negotiations but-first amount-negotiations]
  let max-y-value max(amount-negotiations)
  set-current-plot "Number of negotiations in this cycle"
  set-plot-x-range ifelse-value (ticks < display-last-x-cycles)[0][ticks - display-last-x-cycles] ticks
  set-plot-y-range 0 ifelse-value (max-y-value > 10) [max-y-value][10]

  ;;percentage from asking price plot
  set-current-plot "Percentage from asking price"
  ifelse (percentage = [] )
  [set-plot-x-range 90 110]

  [set-plot-x-range floor(min(percentage)) ceiling(max(percentage))]
  histogram percentage
end
@#$#@#$#@
GRAPHICS-WINDOW
863
16
1486
640
-1
-1
15.0
1
12
1
1
1
0
1
1
1
-20
20
-20
20
1
1
1
ticks
30.0

PLOT
643
18
861
182
Percentage from asking price
%
#
0.0
100.0
40.0
40.0
true
false
"" ""
PENS
"pen-0" 1.0 0 -7500403 true "" ""

PLOT
643
246
859
411
House price distribution
€
NIL
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"For sale" 1.0 0 -7500403 true "" ""

SLIDER
12
35
106
68
gridslider
gridslider
1
9
6.0
1
1
NIL
HORIZONTAL

BUTTON
309
35
373
68
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
211
35
295
68
Setup
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

SLIDER
13
82
185
115
initial-occupation
initial-occupation
10
100
70.0
10
1
%
HORIZONTAL

SLIDER
13
127
209
160
initial-house-occupation
initial-house-occupation
10
100
70.0
10
1
%
HORIZONTAL

PLOT
658
427
858
577
Houses
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
"default" 1.0 0 -16777216 true "" "plot count houses with [ not is-owner? my-owner ]"
"pen-1" 1.0 0 -14070903 true "plot count houses" "plot count houses "
"pen-2" 1.0 0 -1184463 true "" "plot count houses with [is-owner? my-owner ]"

BUTTON
311
78
375
111
Go 1x
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

SLIDER
13
172
185
205
loan-duration
loan-duration
15
30
25.0
5
1
years
HORIZONTAL

MONITOR
658
191
846
236
Total amount of house switches
total-moves
17
1
11

SLIDER
15
215
187
248
max-amount-houses
max-amount-houses
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
262
281
295
max-negotiations-per-tick
max-negotiations-per-tick
0
15
3.0
1
1
% of owners
HORIZONTAL

SLIDER
16
308
188
341
price-gap
price-gap
0
5000
3000.0
500
1
NIL
HORIZONTAL

PLOT
387
19
633
169
Number of negotiations in this cycle
NIL
occurences
0.0
10.0
0.0
10.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count negotiations"

SLIDER
430
169
602
202
display-last-x-cycles
display-last-x-cycles
10
100
80.0
5
1
NIL
HORIZONTAL

MONITOR
215
127
296
172
month
month
0
1
11

MONITOR
215
75
272
120
year
year
17
1
11

CHOOSER
430
214
568
259
buyer-strategy
buyer-strategy
"nothing specific" "overbidding" "underbidding"
1

SLIDER
215
176
387
209
mean-income
mean-income
20000
35000
27000.0
1000
1
€
HORIZONTAL

SLIDER
214
219
386
252
mean-savings
mean-savings
5000
80000
45000.0
5000
1
€
HORIZONTAL

SLIDER
16
350
208
383
max-amount-negotiations
max-amount-negotiations
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
197
308
423
341
max-competitors-for-one-house
max-competitors-for-one-house
1
10
6.0
1
1
NIL
HORIZONTAL

SLIDER
232
351
404
384
buyers-lower-limit
buyers-lower-limit
.75
1
0.9
.05
1
NIL
HORIZONTAL

SLIDER
434
351
606
384
buyers-upper-limit
buyers-upper-limit
1
1.25
1.15
.05
1
NIL
HORIZONTAL

SLIDER
327
272
499
305
overbid-percentaage
overbid-percentaage
0
50
18.0
1
1
NIL
HORIZONTAL

SWITCH
446
310
627
343
moving-in-and-out-city
moving-in-and-out-city
0
1
-1000

TEXTBOX
502
258
652
310
Property bidding model for the\nDutch housing market\nA.H. (Bart) Ziengs\nDelft University of Technology
10
0.0
1

MONITOR
303
127
381
172
succes rate
(test-person-succes / total-moves) / 0.01
17
1
11

SLIDER
224
393
432
426
city-entry-and-leave-rate
city-entry-and-leave-rate
0
10
4.0
1
1
%
HORIZONTAL

@#$#@#$#@
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
true
0
Polygon -7500403 true true 180 15 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 285 165 285 225 285 225 15 180 15
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

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
NetLogo 6.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
