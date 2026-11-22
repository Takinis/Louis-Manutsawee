-- Two additional lines for each entry in ia_manutsawee.lua.
return {
    ACTIONFAIL = {
        REPAIRBOAT = {
            GENERIC = {
                "The hull is sound as it is.",
                "I'll save the patch for an actual leak.",
            },
        },
        EMBARK = {
            INUSE = {
                "After you. I've time to wait.",
                "Let me know when you're finished.",
            },
        },
        INSPECTBOAT = {
            INUSE = {
                "After you. I've time to wait.",
                "Let me know when you're finished.",
            },
        },
        OPEN_CRAFTING = {
            FLOODED = {
                "I can't lay my tools down in this water.",
                "I'll find some dry ground to work on.",
            },
        },
    },
    ANNOUNCE_MAGIC_FAIL = {
        "I'm still standing in the same place.",
        "Strange. I felt nothing happen.",
    },
    ANNOUNCE_SHARX = {
        "A fin off the stern!",
        "Keep your hands inside the boat.",
    },
    ANNOUNCE_TREASURE = {
        "There's a cross on the map.",
        "I'll bring the shovel along.",
    },
    ANNOUNCE_TREASURE_DISCOVER = {
        "There's something buried just here.",
        "I heard the shovel strike something!",
    },
    ANNOUNCE_MORETREASURE = {
        "There's something buried just here.",
        "I heard the shovel strike something!",
    },
    ANNOUNCE_OTHER_WORLD_TREASURE = {
        "None of these islands match my map.",
        "I'll save this chart for another sea.",
    },
    ANNOUNCE_OTHER_WORLD_PLANT = {
        "I can't get it to take root here.",
        "We should take it back to its own soil.",
    },
    ANNOUNCE_IA_MESSAGEBOTTLE = {
        {
            "The salt washed out every word.",
            "All that survived was the paper.",
        },
    },
    ANNOUNCE_VOLCANO_ERUPT = {
        "Look up! Stones are falling!",
        "Find open ground!",
    },
    ANNOUNCE_MAPWRAP_WARN = {
        "I can hardly see past the bow.",
        "Keep close in this fog.",
    },
    ANNOUNCE_MAPWRAP_LOSECONTROL = {
        "I can hardly see past the bow.",
        "Keep close in this fog.",
    },
    ANNOUNCE_MAPWRAP_RETURN = {
        "There's the horizon again!",
        "Let me get my bearings after all that fog.",
    },
    ANNOUNCE_CRAB_ESCAPE = {
        "It went straight under the sand!",
        "Those little legs are faster than they look.",
    },
    ANNOUNCE_TRAWL_FULL = {
        "The net's dragging. Give me a hand!",
        "Time to see what we caught.",
    },
    ANNOUNCE_BOAT_DAMAGED = {
        "Water under the boards! Pass me a patch.",
        "I can feel water round my ankles.",
    },
    ANNOUNCE_BOAT_SINKING = {
        "Everyone to shore! Leave the cargo!",
        "The deck's going under!",
    },
    ANNOUNCE_BOAT_SINKING_IMMINENT = {
        "Everyone to shore! Leave the cargo!",
        "The deck's going under!",
    },
    ANNOUNCE_WAVE_BOOST = {
        "That wave gave us quite a lift!",
        "Hold on, we're picking up speed!",
    },
    ANNOUNCE_WHALE_HUNT_BEAST_NEARBY = {
        "Fresh signs. It can't be far.",
        "Quiet now. We're close.",
    },
    ANNOUNCE_WHALE_HUNT_LOST_TRAIL = {
        "Nothing past this point.",
        "I can't tell where it went from here.",
    },
    ANNOUNCE_WHALE_HUNT_LOST_TRAIL_SPRING = {
        "Nothing past this point.",
        "I can't tell where it went from here.",
    },
    DESCRIBE = {
        FLOTSAM = {
            "Something from a ship, judging by the splinters.",
            "I wonder which shore it started from.",
        },
        SUNKEN_BOAT = {
            ABANDONED = {
                "Nobody seems to be tending it now.",
                "I wonder when someone last came this way.",
            },
            GENERIC = {
                "I wonder what Wickerbottom could tell me about the sunken boat.",
                "I'll keep it separate until I know what it's for.",
            },
        },
        SUNKEN_BOAT_BURNT = {
            "Water all around and it still burned.",
            "The water hasn't washed away the scorch marks.",
        },
        BOAT_LOGRAFT = {
            "I'll keep my things tied down between the logs.",
            "I can see the water between my toes.",
        },
        BOAT_RAFT = {
            "I'll keep my things tied down between the logs.",
            "I can see the water between my toes.",
        },
        BOAT_ROW = {
            "I'll have a look at the row boat while the water's calm.",
            "It's easier to sort things out here than in rough seas.",
        },
        BOAT_CARGO = {
            "I wonder what a heavy swell would do to the cargo boat.",
            "Someone keep an eye on the current while I do this.",
        },
        BOAT_ARMOURED = {
            "I wonder what a heavy swell would do to the armored boat.",
            "It's easier to sort things out here than in rough seas.",
        },
        BOAT_ENCRUSTED = {
            "I wonder what a heavy swell would do to the encrusted boat.",
            "I won't go far from the dock until it's ready.",
        },
        CAPTAINHAT = {
            "I should tuck my fringe back before trying on the captain hat.",
            "I'd take a look in a mirror before going out.",
        },
        BOAT_TORCH = {
            "I wonder what a heavy swell would do to the boat torch.",
            "It's easier to sort things out here than in rough seas.",
        },
        BOAT_LANTERN = {
            "I'll have a look at the boat lantern while the water's calm.",
            "I remember setting aside the empty bottle to make this.",
        },
        BOATREPAIRKIT = {
            "I ought to make a place for the boat repair kit in my pack.",
            "I remember setting aside the rope to make this.",
        },
        BOATCANNON = {
            "I ought to make a place for the boat cannon in my pack.",
            "I remember setting aside the log to make this.",
        },
        BOTTLELANTERN = {
            "I'd like to show the bottle lantern to someone back at camp.",
            "I can see where the bioluminescence went into it.",
        },
        BIOLUMINESCENCE = {
            "I ought to make a place for the bioluminescence in my pack.",
            "I'll need this if I decide to make the bottle lantern.",
        },
        BALLPHIN = {
            "Where would I find the bottlenose ballphin after dark?",
            "I won't stand between it and its way home.",
        },
        BALLPHINHOUSE = {
            "I wonder if anyone's home at the ballphin palace today.",
            "I'll leave the entrance clear.",
        },
        DORSALFIN = {
            "Could we take the dorsal fin on the road with us?",
            "That reminds me, we could make the castaway with some of this.",
        },
        TUNACAN = {
            "I'd like to show the \"ballphin free\" tuna to someone back at camp.",
            "I could save it for someone who needs it.",
        },
        JELLYFISH = {
            "I can see the jellyfish through the water.",
            "I'll stay still until the surface clears.",
        },
        JELLYFISH_DEAD = {
            "I can see the dead jellyfish through the water.",
            "I'll stay still until the surface clears.",
        },
        JELLYFISH_COOKED = {
            "I should let the cooked jellyfish cool before I take a bite.",
            "Shall I split this so we can both taste it?",
        },
        JELLYFISH_PLANTED = {
            "I'll leave a marker by these leaves.",
            "I'll take a closer look without pulling at the roots.",
        },
        JELLYJERKY = {
            "I can take the dried jellyfish along without a bowl.",
            "I like provisions I can tuck into a sleeve.",
        },
        RAINBOWJELLYFISH = {
            "A little ripple gave the rainbow jellyfish away.",
            "The light changes so much beneath the waves.",
        },
        RAINBOWJELLYFISH_DEAD = {
            "I can see the dead rainbow jellyfish through the water.",
            "The light changes so much beneath the waves.",
        },
        RAINBOWJELLYFISH_COOKED = {
            "I'd like a little salt with the cooked rainbow jellyfish.",
            "Hot food is worth the wait.",
        },
        RAINBOWJELLYFISH_PLANTED = {
            "I'd remember where that patch grows.",
            "I'll take a closer look without pulling at the roots.",
        },
        JELLYOPOP = {
            "I'd eat it before the sun melts the edges.",
            "A cold treat is just what I wanted.",
        },
        CROCODOG = {
            "I'd give the crocodog room to turn.",
            "I'd like to know where it shelters.",
        },
        POISONCROCODOG = {
            "I can just make out the poison crocodog from here.",
            "I'd like to know where it shelters.",
        },
        WATERCROCODOG = {
            "I'd give the water crocodog room to turn.",
            "It knows this ground better than I do.",
        },
        PURPLE_GROUPER = {
            "The colours on the purple grouper are even brighter in the water.",
            "I could watch those fins turn in the light all afternoon.",
        },
        PIERROT_FISH = {
            "A little ripple gave the pierrot fish away.",
            "The light changes so much beneath the waves.",
        },
        NEON_QUATTRO = {
            "The colours on the neon quattro are even brighter in the water.",
            "I could watch those fins turn in the light all afternoon.",
        },
        PURPLE_GROUPER_COOKED = {
            "I'd like a little salt with the cooked purple grouper.",
            "Shall I split this so we can both taste it?",
        },
        PIERROT_FISH_COOKED = {
            "I could smell the cooked pierrot fish before I saw it.",
            "Hot food is worth the wait.",
        },
        NEON_QUATTRO_COOKED = {
            "Someone saved me a portion of the cooked neon quattro.",
            "I'll keep the last bit for the walk back.",
        },
        TROPICALBOUILLABAISSE = {
            "I'd save a serving of the tropical bouillabaisse for the person who cooked.",
            "This is worth getting a clean plate for.",
        },
        FISH_FARM = {
            EMPTY = {
                "There's nothing in the fish farm at the moment.",
                "I can see right to the bottom.",
            },
            STOCKED = {
                "The roe is in. Now we wait.",
                "I can check the water without disturbing the pen.",
            },
            ONEFISH = {
                "One little fish in the pen.",
                "I can check the water without disturbing the pen.",
            },
            TWOFISH = {
                "Two fish! They keep darting past each other.",
                "I can check the water without disturbing the pen.",
            },
            REDFISH = {
                "I can see more fish gathering under the surface.",
                "I can check the water without disturbing the pen.",
            },
            BLUEFISH = {
                "The whole pen is busy with fins now.",
                "I can check the water without disturbing the pen.",
            },
        },
        ROE = {
            "Could we take the roe on the road with us?",
            "Something to look forward to on the way home.",
        },
        ROE_COOKED = {
            "I'd like a little salt with the cooked roe.",
            "Shall I split this so we can both taste it?",
        },
        CAVIAR = {
            "I'd like to share the caviar after practice.",
            "I'll get the plates out.",
        },
        CORMORANT = {
            "I'd like to sketch the cormorant with its wings spread.",
            "There's a feather caught in the breeze.",
        },
        SEAGULL = {
            "I'd like to sketch the seagull with its wings spread.",
            "There's a feather caught in the breeze.",
        },
        SEAGULL_WATER = {
            "I can see the seagull through the water.",
            "The light changes so much beneath the waves.",
        },
        TOUCAN = {
            "I recognized the toucan by the beak.",
            "I'd have to sit quite still to see it land again.",
        },
        PARROT = {
            "I recognized the parrot by the beak.",
            "There's a feather caught in the breeze.",
        },
        PARROT_PIRATE = {
            "I'd like to sketch the pirate parrot with its wings spread.",
            "There's a feather caught in the breeze.",
        },
        SEA_YARD = {
            ON = {
                "I can see the change in the sea yard from here.",
                "Good. We can make use of it now.",
            },
            OFF = {
                "All quiet around the sea yard for the moment.",
                "I wonder what would start it again.",
            },
            LOWFUEL = {
                "I ought to top up the sea yard.",
                "I'll go fetch fuel before it runs out.",
            },
        },
        SEA_CHIMINEA = {
            EMBERS = {
                "There's hardly a glow left in the buoyant chiminea.",
                "I can barely see my hands by this light.",
            },
            GENERIC = {
                "I'd like to see the buoyant chiminea in daylight.",
                "I remember setting aside the tar to make this.",
            },
            HIGH = {
                "I can feel the buoyant chiminea from several paces back.",
                "That's quite enough fuel for now.",
            },
            LOW = {
                "I ought to top up the buoyant chiminea.",
                "I'll go fetch fuel before it runs out.",
            },
            NORMAL = {
                "I could sit beside the buoyant chiminea for a while.",
                "Just right. No need to feed it yet.",
            },
            OUT = {
                "There isn't a flicker left in the buoyant chiminea.",
                "We'll have to light it again.",
            },
        },
        CHIMINEA = {
            "I'd stop by the chiminea again when we have more time.",
            "I remember setting aside the log to make this.",
        },
        TAR_EXTRACTOR = {
            ON = {
                "There. the tar extractor is working.",
                "Good. We can make use of it now.",
            },
            OFF = {
                "No sign of activity from the tar extractor.",
                "I can get a closer look while it's still.",
            },
            LOWFUEL = {
                "I ought to top up the tar extractor.",
                "I'll go fetch fuel before it runs out.",
            },
        },
        TAR = {
            "I wonder what Wickerbottom could tell me about the tar.",
            "I should save some for the tar suit.",
        },
        TAR_TRAP = {
            "I'd mark the spot where we leave the tar trap.",
            "I'll let the others know to tread carefully here.",
        },
        TAR_POOL = {
            "I'd like to see the tar slick by daylight before we go farther.",
            "I'll make a note of the nearest shelter.",
        },
        TARLAMP = {
            "I'd like the tar lamp near the path after dusk.",
            "I'll have to set aside the seashell if I make another.",
        },
        TARSUIT = {
            "I could wear the tar suit over my training clothes.",
            "I remember setting aside the tar to make this.",
        },
        PIRATIHATITATOR = {
            GENERIC = {
                "Would the piratihatitator leave any room for my glasses?",
                "I remember setting aside the parrot to make this.",
            },
            BURNT = {
                "There's a black mark where the piratihatitator stood.",
                "I'll see what survived nearby.",
            },
        },
        PIRATEHAT = {
            "Would the pirate hat leave any room for my glasses?",
            "I should save some for the piratihatitator.",
        },
        MUSSEL_FARM = {
            GENERIC = {
                "I'd like to see the mussels in daylight.",
                "Next time I'll bring my notebook.",
            },
            STICKPLANTED = {
                "The stick's anchored where the mussels can settle.",
                "I'll come back to see what gathers on the wood.",
            },
        },
        MUSSEL = {
            "I'd like to share the mussel after practice.",
            "I'll need this if I decide to make the mussel bed.",
        },
        MUSSEL_COOKED = {
            "I should let the cooked mussel cool before I take a bite.",
            "I'll keep the last bit for the walk back.",
        },
        MUSSELBOUILLABAISE = {
            "I'd bring the mussel bouillabaise straight to the table.",
            "I'd like to taste it before it gets cold.",
        },
        MUSSEL_BED = {
            "I wonder what Wickerbottom could tell me about the mussel bed.",
            "I'll have to set aside the mussel if I make another.",
        },
        MUSSEL_STICK = {
            "I'd like to show the mussel stick to someone back at camp.",
            "I can see where the seaweed went into it.",
        },
        LOBSTER = {
            "I can see the wobster through the water.",
            "The light changes so much beneath the waves.",
        },
        LOBSTER_DEAD = {
            "I'll take it to the stove while it's still fresh.",
            "We can make something with today's catch.",
        },
        LOBSTER_DEAD_COOKED = {
            "Someone saved me a portion of the delicious wobster.",
            "Hot food is worth the wait.",
        },
        LOBSTERHOLE = {
            "I'll mark the wobster den on my map.",
            "Let's keep the way back in sight.",
        },
        WOBSTERBISQUE = {
            "I'd like to share the wobster bisque after practice.",
            "I'll get the plates out.",
        },
        WOBSTERDINNER = {
            "I'll save the wobster dinner for a meal we can eat sitting down.",
            "A smaller portion for me if we're sharing.",
        },
        SEATRAP = {
            "I want to know exactly where the sea trap is set.",
            "Nobody should stumble into this on the way home.",
        },
        BUSH_VINE = {
            BURNING = {
                "Flames on the viney bush!",
                "Let me get at those flames!",
            },
            BURNT = {
                "I won't get any more use out of the viney bush.",
                "That smell stays on my sleeves.",
            },
            CHOPPED = {
                "Nothing of the viney bush above the stump now.",
                "I'll leave room for a new tree.",
            },
            GENERIC = {
                "I want to look at the viney bush in better light.",
                "I'd leave room for new growth.",
            },
        },
        VINE = {
            "I'd like to see the vine in daylight.",
            "I should save some for the jungle turf.",
        },
        DUG_BUSH_VINE = {
            "I know a patch of soil for the viney bush root.",
            "A little earth around the roots should help.",
        },
        ROCK_LIMPET = {
            GENERIC = {
                "I can feel the weight of the limpet rock just looking at it.",
                "The colour changes where the surface has worn away.",
            },
            PICKED = {
                "We should give the limpet rock time to grow back.",
                "I'll check it on my next walk.",
            },
        },
        LIMPETS = {
            "I'd like to know what Warly would serve with the limpets.",
            "Supper's better when we can all sit down together.",
        },
        LIMPETS_COOKED = {
            "I'd like a little salt with the cooked limpets.",
            "I should eat before practice this time.",
        },
        BISQUE = {
            "I'd like to share the bisque after practice.",
            "I'll get the plates out.",
        },
        MACHETE = {
            "I'd like to feel the balance of the machete.",
            "I should save some for the obsidian machete.",
        },
        GOLDENMACHETE = {
            "I'd like to feel the balance of the luxury machete.",
            "I can see where the gold nugget went into it.",
        },
        THATCHPACK = {
            "I ought to check what's already in the thatch pack.",
            "I'd like one place where my glasses won't get crushed.",
        },
        PIRATEPACK = {
            "I'd put the things I don't need yet in the booty bag.",
            "It pays to know where you put the spare supplies.",
        },
        SEASACK = {
            "I'd put the things I don't need yet in the sea sack.",
            "I can see where the seaweed went into it.",
        },
        SEAWEED_PLANTED = {
            GENERIC = {
                "I'd remember where that patch grows.",
                "I want to see how it grows in this soil.",
            },
            PICKED = {
                "We should give the seaweed time to grow back.",
                "Best to leave the roots undisturbed now.",
            },
        },
        SEAWEED = {
            "I could smell the seaweed from the other side of camp.",
            "I'll need this if I decide to make the encrusted bumper kit.",
        },
        SEAWEED_COOKED = {
            "I could smell the roasted seaweed before I saw it.",
            "Shall I split this so we can both taste it?",
        },
        SEAWEED_DRIED = {
            "I can take the dried seaweed along without a bowl.",
            "I like provisions I can tuck into a sleeve.",
        },
        SEAWEED_STALK = {
            "I know a patch of soil for the seaweed stalk.",
            "A little earth around the roots should help.",
        },
        DUBLOON = {
            "Even after the crossing I can read the stamp.",
            "I'll count these on land. Too easy to drop one here.",
        },
        SLOTMACHINE = {
            "I'd watch the slot machine at work before adjusting anything.",
            "I'd ask before I took the cover off.",
        },
        SOLOFISH = {
            "A little ripple gave the dogfish away.",
            "The light changes so much beneath the waves.",
        },
        SOLOFISH_DEAD = {
            "I'll take it to the stove while it's still fresh.",
            "We can make something with today's catch.",
        },
        SWORDFISH = {
            "The swordfish takes a different grip from my katana.",
            "A light touch tells me more than a hard swing.",
        },
        SWORDFISH_DEAD = {
            "I'd check the grip on the dead swordfish before taking it out.",
            "A light touch tells me more than a hard swing.",
        },
        CUTLASS = {
            "I wonder who first thought to make the cutlass supreme this shape.",
            "I remember setting aside the dead swordfish to make this.",
        },
        SUNKEN_BOAT_TRINKET_1 = {
            "What would the Pig King make of it?",
            "I can always spare one little corner of my pack.",
        },
        SUNKEN_BOAT_TRINKET_2 = {
            "Of all the things to turn up here, it!",
            "I'll wipe it clean before I show anyone.",
        },
        SUNKEN_BOAT_TRINKET_3 = {
            "What would the Pig King make of it?",
            "I wonder what it looked like when it was new.",
        },
        SUNKEN_BOAT_TRINKET_4 = {
            "Of all the things to turn up here, the sea worther!",
            "I can always spare one little corner of my pack.",
        },
        SUNKEN_BOAT_TRINKET_5 = {
            "Somebody kept it long enough for us to find it.",
            "I can always spare one little corner of my pack.",
        },
        TRINKET_IA_13 = {
            "Somebody kept the orange soda long enough for us to find it.",
            "Perhaps someone at camp will recognize this.",
        },
        TRINKET_IA_14 = {
            "Takina would ask why I kept the voodoo doll.",
            "I wonder what it looked like when it was new.",
        },
        TRINKET_IA_15 = {
            "I'd like to know who once owned the ukulele.",
            "I wonder what it looked like when it was new.",
        },
        TRINKET_IA_16 = {
            "Takina would ask why I kept the license plate.",
            "Perhaps someone at camp will recognize this.",
        },
        TRINKET_IA_17 = {
            "Of all the things to turn up here, the old boot!",
            "I can always spare one little corner of my pack.",
        },
        TRINKET_IA_18 = {
            "What would the Pig King make of the ancient vase?",
            "Perhaps someone at camp will recognize this.",
        },
        TRINKET_IA_19 = {
            "Of all the things to turn up here, the brain cloud pill!",
            "I can always spare one little corner of my pack.",
        },
        TRINKET_IA_20 = {
            "What would the Pig King make of the sextant?",
            "I wonder what it looked like when it was new.",
        },
        TRINKET_IA_21 = {
            "I'd like to know who once owned the toy boat.",
            "Perhaps someone at camp will recognize this.",
        },
        TRINKET_IA_22 = {
            "Takina would ask why I kept the wine bottle candle.",
            "Whatever its worth, someone took the trouble to make it.",
        },
        TRINKET_IA_23 = {
            "Of all the things to turn up here, the broken aac device!",
            "Perhaps someone at camp will recognize this.",
        },
        EARRING = {
            "I hadn't expected to find the one true earring out here.",
            "I'll turn it over and have a look at the other side.",
        },
        TURF_BEACH = {
            "I'd like to try it outside the gate.",
            "Let's see how it looks beside the old path.",
        },
        TURF_JUNGLE = {
            "I'll lay the jungle turf where the bare ground shows.",
            "I should line up the edges before I set it down.",
        },
        TURF_MAGMAFIELD = {
            "I know that ground by the feel of it underfoot.",
            "I'll have to set aside the nitre if I make another.",
        },
        TURF_TIDALMARSH = {
            "I'd like to try the tidal marsh turf outside the gate.",
            "Let's see how it looks beside the old path.",
        },
        TURF_ASH = {
            "I know that ground by the feel of it underfoot.",
            "Let's see how it looks beside the old path.",
        },
        TURF_MEADOW = {
            "A patch of the meadow turf would change the whole path.",
            "I should line up the edges before I set it down.",
        },
        TURF_VOLCANO = {
            "I know that ground by the feel of it underfoot.",
            "I should line up the edges before I set it down.",
        },
        TURF_SNAKESKIN = {
            "I'll lay the snakeskin rug where the bare ground shows.",
            "I could mark the turn in the path with this.",
        },
        WHALE_BLUE = {
            "That's a whale's trail, sure enough.",
            "I ought to watch where the next spout comes up.",
        },
        WHALE_CARCASS_BLUE = {
            "It lies so still. I'll give it a little room.",
            "I wonder what left it here like this.",
        },
        WHALE_WHITE = {
            "That's a whale's trail, sure enough.",
            "I ought to watch where the next spout comes up.",
        },
        WHALE_CARCASS_WHITE = {
            "It lies so still. I'll give it a little room.",
            "I wonder what left it here like this.",
        },
        WHALE_TRACK = {
            "That's a whale's trail, sure enough.",
            "I ought to watch where the next spout comes up.",
        },
        WHALE_BUBBLES = {
            "I wonder what the suspicious bubbles looked like when this place was new.",
            "I'll walk round it once for a better look.",
        },
        BLUBBERSUIT = {
            "I could wear the blubber suit over my training clothes.",
            "I can mend a small tear before it gets worse.",
        },
        BLUBBER = {
            "I could smell the blubber from the other side of camp.",
            "I should save some for the windbreaker.",
        },
        HARPOON = {
            "I wonder who first thought to make the harpoon this shape.",
            "I should make time to practice before I need it.",
        },
        SAIL_PALMLEAF = {
            "I'll have a look at the thatch sail while the water's calm.",
            "I won't go far from the dock until it's ready.",
        },
        SAIL_CLOTH = {
            "I wonder what a heavy swell would do to the cloth sail.",
            "I remember setting aside the bamboo to make this.",
        },
        SAIL_SNAKESKIN = {
            "I'll check the snakeskin sail before we leave the shore.",
            "I won't go far from the dock until it's ready.",
        },
        SAIL_FEATHER = {
            "I'll have a look at the feather lite sail while the water's calm.",
            "I'll have to set aside the bamboo if I make another.",
        },
        IRONWIND = {
            "I'd like to show the iron wind to someone back at camp.",
            "I remember setting aside the gold nugget to make this.",
        },
        BERMUDATRIANGLE = {
            "I'll mark the spot where we found the electric isosceles.",
            "Somebody at camp might know its story.",
        },
        PACKIM_FISHBONE = {
            "Takina would make a list of everything in the fishbone.",
            "I'll keep the things we need first near the top.",
        },
        PACKIM = {
            "I'd put the things I don't need yet in the packim baggims.",
            "I'd like one place where my glasses won't get crushed.",
        },
        TIGERSHARK = {
            "I can just make out the tiger shark from here.",
            "It knows this ground better than I do.",
        },
        MYSTERYMEAT = {
            "Could we take the bile-covered slop on the road with us?",
            "Something to look forward to on the way home.",
        },
        SHARK_GILLS = {
            "I'd bring the shark gills back for a closer look.",
            "I'll need this if I decide to make the dumbrella.",
        },
        TIGEREYE = {
            "I'd like to know what Warly would serve with the eye of the tiger shark.",
            "I should save some for the super spyglass.",
        },
        DOUBLE_UMBRELLAHAT = {
            "I should tuck my fringe back before trying on the dumbrella.",
            "I remember setting aside the shark gills to make this.",
        },
        SHARKITTEN = {
            "I'd like to watch the sharkitten from somewhere quiet.",
            "I won't stand between it and its way home.",
        },
        SHARKITTENSPAWNER = {
            GENERIC = {
                "I wonder what the sandy pile looked like when this place was new.",
                "I'll walk round it once for a better look.",
            },
            INACTIVE = {
                "No sign of activity from the sandy pile.",
                "I can get a closer look while it's still.",
            },
        },
        WOODLEGS_KEY1 = {
            "I'll keep the bone key in its own pocket.",
            "I'd remember which way the teeth point.",
        },
        WOODLEGS_KEY2 = {
            "Somewhere there's a lock made for the golden key.",
            "I'd remember which way the teeth point.",
        },
        WOODLEGS_KEY3 = {
            "I'll keep the iron key in its own pocket.",
            "I'd remember which way the teeth point.",
        },
        WOODLEGS_CAGE = {
            "Can you hear me through the bars, Captain?",
            "I'll take a look at those locks.",
        },
        CORAL = {
            "I'd set the coral beside the rest of my supplies.",
            "That reminds me, we could make the anti venom with some of this.",
        },
        ROCK_CORAL = {
            "I can feel the weight of the coral reef just looking at it.",
            "The colour changes where the surface has worn away.",
        },
        LIMESTONENUGGET = {
            "There's a grain to the limestone if you look closely.",
            "I ought to ask the smith what to make of this.",
        },
        NUBBIN = {
            "I'd like to show the coral nubbin to someone back at camp.",
            "I'll have to set aside the limestone if I make another.",
        },
        CORALLARVE = {
            "I ought to make a place for the coral larva in my pack.",
            "I should save some for the coral nubbin.",
        },
        WALL_LIMESTONE = {
            "With the limestone wall here, the camp would have a proper boundary.",
            "We'll want an opening wide enough for our beefalo.",
        },
        WALL_LIMESTONE_ITEM = {
            "With the limestone wall here, the camp would have a proper boundary.",
            "I can see where the limestone went into it.",
        },
        WALL_ENFORCEDLIMESTONE = {
            "I'll check the alignment of the sea wall against the next section.",
            "We'll want an opening wide enough for our beefalo.",
        },
        WALL_ENFORCEDLIMESTONE_ITEM = {
            "With the sea wall here, the camp would have a proper boundary.",
            "I'll have to set aside the limestone if I make another.",
        },
        ARMORLIMESTONE = {
            "I could wear the limestone suit over my training clothes.",
            "I'll check the fastening twice.",
        },
        CORAL_BRAIN_ROCK = {
            "I'd like a closer look at the surface of the brainy sprout.",
            "The colour changes where the surface has worn away.",
        },
        CORAL_BRAIN = {
            "I hope there's enough of the brainy matter to share.",
            "I should save some for the brain of thought.",
        },
        BRAINJELLYHAT = {
            "Would the brain of thought leave any room for my glasses?",
            "I like to keep my line of sight clear.",
        },
        SEASHELL = {
            "I wonder what I could make with the seashell.",
            "I'll need this if I decide to make the sand castle.",
        },
        SEASHELL_BEACHED = {
            "I'd stop by the seashell again when we have more time.",
            "Next time I'll bring my notebook.",
        },
        ARMORSEASHELL = {
            "I could wear the seashell suit over my training clothes.",
            "I can mend a small tear before it gets worse.",
        },
        ARMOR_LIFEJACKET = {
            "I'd check the fit of the life jacket before I rely on it.",
            "I'll have to set aside the cloth if I make another.",
        },
        ARMOR_WINDBREAKER = {
            "I could wear the windbreaker over my training clothes.",
            "I can mend a small tear before it gets worse.",
        },
        SNAKE = {
            "I'd like to watch the snake from somewhere quiet.",
            "I can tell more by watching than by chasing it.",
        },
        SNAKE_POISON = {
            "I'd label the poison snake before I put it with the supplies.",
            "I'd like to know what's in it before I try it.",
        },
        SNAKESKIN = {
            "I'd bring the snakeskin back for a closer look.",
            "I should save some for the snakeskin hat.",
        },
        SNAKEOIL = {
            "I wonder what Wickerbottom could tell me about the snake oil.",
            "I should look it over in better light.",
        },
        SNAKESKINHAT = {
            "Let me try the snakeskin hat with my hair tied back.",
            "I like to keep my line of sight clear.",
        },
        ARMOR_SNAKESKIN = {
            "I want to see whether I can turn freely in the snakeskin jacket.",
            "I'll check the fastening twice.",
        },
        SNAKEDEN = {
            BURNING = {
                "Flames on the viney bush!",
                "Let me get at those flames!",
            },
            BURNT = {
                "Nothing left of the viney bush but ash.",
                "I'll see what survived nearby.",
            },
            CHOPPED = {
                "That's a fresh cut on the viney bush.",
                "I'll leave room for a new tree.",
            },
            GENERIC = {
                "I'd approach the viney bush quietly enough to hear who's in there.",
                "I'll leave the entrance clear.",
            },
        },
        OBSIDIANFIREPIT = {
            EMBERS = {
                "There's hardly a glow left in the obsidian fire pit.",
                "I can barely see my hands by this light.",
            },
            GENERIC = {
                "I ought to remember the way back to the obsidian fire pit.",
                "I remember setting aside the obsidian to make this.",
            },
            HIGH = {
                "I can feel the obsidian fire pit from several paces back.",
                "That's quite enough fuel for now.",
            },
            LOW = {
                "I ought to top up the obsidian fire pit.",
                "A little now will save me trouble later.",
            },
            NORMAL = {
                "I could sit beside the obsidian fire pit for a while.",
                "Just right. No need to feed it yet.",
            },
            OUT = {
                "I remember the obsidian fire pit giving rather more light than this.",
                "I should find something to light it with.",
            },
        },
        OBSIDIAN = {
            "Could we take the obsidian on the road with us?",
            "I should save some for the obsidian coconade.",
        },
        ROCK_OBSIDIAN = {
            "I'd like a closer look at the surface of the obsidian boulder.",
            "The colour changes where the surface has worn away.",
        },
        OBSIDIAN_WORKBENCH = {
            "I wonder what the obsidian workbench looked like when this place was new.",
            "I want to know why it's here in this particular spot.",
        },
        OBSIDIANAXE = {
            "The obsidian axe takes a different grip from my katana.",
            "I'll have to set aside the axe if I make another.",
        },
        OBSIDIANMACHETE = {
            "I'll keep the obsidian machete where it won't catch on my sleeve.",
            "My teacher always checked the fittings first.",
        },
        SPEAR_OBSIDIAN = {
            "I'll keep the obsidian spear where it won't catch on my sleeve.",
            "I should wipe the handle before I put it away.",
        },
        VOLCANOSTAFF = {
            "I'll keep the volcano staff where it won't catch on my sleeve.",
            "I'll keep it dry on the walk back.",
        },
        ARMOROBSIDIAN = {
            "I want to see whether I can turn freely in the obsidian armor.",
            "I'll check the fastening twice.",
        },
        COCONADE = {
            BURNING = {
                "Flames on the coconade!",
                "Quick, before the next thing catches!",
            },
            GENERIC = {
                "I wonder what Wickerbottom could tell me about the coconade.",
                "I'll need this if I decide to make the obsidian coconade.",
            },
        },
        OBSIDIANCOCONADE = {
            BURNING = {
                "Flames on the obsidian coconade!",
                "Has anyone brought water?",
            },
            GENERIC = {
                "I'd like to show the obsidian coconade to someone back at camp.",
                "I can see where the dragoon heart went into it.",
            },
        },
        VOLCANO_ALTAR = {
            GENERIC = {
                "Someone went to great trouble to leave the volcano altar of snackrifice here.",
                "A moment of quiet here seems fitting.",
            },
            OPEN = {
                "There's a way through the volcano altar of snackrifice now.",
                "I should see where this leads.",
            },
        },
        VOLCANO = {
            "I ought to remember the way back to the volcano.",
            "I should make a quick sketch before we leave.",
        },
        VOLCANO_EXIT = {
            "I ought to remember the route back from the volcano exit.",
            "I'll make a note of the nearest shelter.",
        },
        ROCK_CHARCOAL = {
            "I'd like a closer look at the surface of the charcoal boulder.",
            "The colour changes where the surface has worn away.",
        },
        VOLCANO_SHRUB = {
            "I ought to remember the way back to the burnt ash tree.",
            "I want to know why it's here in this particular spot.",
        },
        LAVAPOOL = {
            "I ought to remember the route back from the lava pool.",
            "Let's keep the way back in sight.",
        },
        COFFEEBUSH = {
            BARREN = {
                "I hate seeing the coffee plant in this condition.",
                "I ought to check the soil here.",
            },
            WITHERED = {
                "I should tend to the coffee plant before I leave.",
                "I ought to check the soil here.",
            },
            GENERIC = {
                "I'd like a drawing of the coffee plant for my notes.",
                "I should mind where I step near the roots.",
            },
            PICKED = {
                "We should give the coffee plant time to grow back.",
                "I'll check it on my next walk.",
            },
        },
        COFFEEBEANS = {
            "I'll grind these just before I brew them.",
            "There's enough for a cup to share.",
        },
        COFFEEBEANS_COOKED = {
            "I'll grind these just before I brew them.",
            "There's enough for a cup to share.",
        },
        DUG_COFFEEBUSH = {
            "I'd like to see the coffee plant growing near camp.",
            "I'd better find a place where no one will tread on it.",
        },
        COFFEE = {
            "That smell alone has me sitting up straighter.",
            "A small cup before morning practice would be lovely.",
        },
        ELEPHANTCACTUS = {
            BARREN = {
                "I should tend to the elephant cactus before I leave.",
                "The leaves have lost their spring.",
            },
            WITHERED = {
                "I hate seeing the elephant cactus in this condition.",
                "I ought to check the soil here.",
            },
            GENERIC = {
                "I'd give the elephant cactus a little room to pass.",
                "I'll stay downwind for a clearer look.",
            },
            PICKED = {
                "There's nothing left to pick from the elephant cactus today.",
                "Best to leave the roots undisturbed now.",
            },
        },
        DUG_ELEPHANTCACTUS = {
            "I know a patch of soil for the elephant cactus.",
            "A little earth around the roots should help.",
        },
        ELEPHANTCACTUS_ACTIVE = {
            "Even from here I can see the lash marks in the sand.",
            "I'd give that cactus a good wide berth.",
        },
        ELEPHANTCACTUS_STUMP = {
            "Even from here I can see the lash marks in the sand.",
            "I'd give that cactus a good wide berth.",
        },
        NEEDLESPEAR = {
            "I'll keep the cactus spike where it won't catch on my sleeve.",
            "I'll keep it dry on the walk back.",
        },
        ARMORCACTUS = {
            "I could wear the cactus armor over my training clothes.",
            "I remember setting aside the cactus spike to make this.",
        },
        TWISTER = {
            "Look, the sealnado has noticed us.",
            "I won't stand between it and its way home.",
        },
        TWISTER_SEAL = {
            "I'd like to sketch the seal before it moves again.",
            "Something made it turn just then.",
        },
        TURBINE_BLADES = {
            "I want to see how they put the turbine blades together.",
            "I'd ask before I took the cover off.",
        },
        MAGIC_SEAL = {
            "I ought to make a place for the magic seal in my pack.",
            "I should save some for the sail stick.",
        },
        WIND_CONCH = {
            "I'd set the howling conch beside the rest of my supplies.",
            "I can see where the purple gem went into it.",
        },
        WINDSTAFF = {
            "I'd like to feel the balance of the sail stick.",
            "I can see where the obsidian went into it.",
        },
        DRAGOON = {
            "Is that the usual gait for the dragoon?",
            "I'll stay downwind for a clearer look.",
        },
        DRAGOONHEART = {
            "I'd set a little of the dragoon heart aside for our guest.",
            "I should save some for the obsidian armor.",
        },
        DRAGOONSPIT = {
            "I ought to remember the way back to the dragoon saliva.",
            "I can see a little more from the other side.",
        },
        DRAGOONEGG = {
            "I wouldn't risk dropping the dragoon egg on the way back.",
            "I'd carry it cupped in both hands.",
        },
        DRAGOONDEN = {
            "I wonder if anyone's home at the dragoon den today.",
            "I shouldn't stand right in the doorway.",
        },
        ICEMAKER = {
            OUT = {
                "I remember the ice maker 3000 giving rather more light than this.",
                "We'll have to light it again.",
            },
            VERYLOW = {
                "There's not much left to keep the ice maker 3000 going.",
                "A little now will save me trouble later.",
            },
            LOW = {
                "There's not much left to keep the ice maker 3000 going.",
                "A little now will save me trouble later.",
            },
            NORMAL = {
                "I could sit beside the ice maker 3000 for a while.",
                "Just right. No need to feed it yet.",
            },
            HIGH = {
                "I can feel the ice maker 3000 from several paces back.",
                "That's quite enough fuel for now.",
            },
        },
        HAIL_ICE = {
            "I could smell the hail from the other side of camp.",
            "I should save some for the ice.",
        },
        BAMBOOTREE = {
            BURNING = {
                "The fire's spreading over the bamboo patch!",
                "Quick, before the next thing catches!",
            },
            BURNT = {
                "I wish I'd reached the bamboo patch before the fire did.",
                "We'd have to start over here.",
            },
            CHOPPED = {
                "That's a fresh cut on the bamboo patch.",
                "I'll leave room for a new tree.",
            },
            GENERIC = {
                "I'd like to see how the bamboo patch changes with the season.",
                "I'd leave room for new growth.",
            },
        },
        BAMBOO = {
            "I wonder what the bamboo looked like when this place was new.",
            "I should save some for the speargun.",
        },
        FABRIC = {
            "I ought to make a place for the cloth in my pack.",
            "I should save some for the gas mask.",
        },
        DUG_BAMBOOTREE = {
            "I'd like to see the bamboo root growing near camp.",
            "A little earth around the roots should help.",
        },
        JUNGLETREE = {
            BURNING = {
                "Flames on the jungle tree!",
                "The smoke's getting in my eyes!",
            },
            BURNT = {
                "There's a black mark where the jungle tree stood.",
                "I'll come back when the embers cool.",
            },
            CHOPPED = {
                "That's a fresh cut on the jungle tree.",
                "I'll leave room for a new tree.",
            },
            GENERIC = {
                "I'd like a drawing of the jungle tree for my notes.",
                "I'd leave room for new growth.",
            },
        },
        JUNGLETREESEED = {
            "I'd like a drawing of the jungle tree seed for my notes.",
            "I could come back tomorrow to see what has changed.",
        },
        JUNGLETREESEED_SAPLING = {
            "I know a patch of soil for the jungle tree sapling.",
            "I'll give the roots room to spread.",
        },
        LIVINGJUNGLETREE = {
            "I'll remember where the regular jungle tree grows.",
            "I could come back tomorrow to see what has changed.",
        },
        OX = {
            "Is that the usual gait for the water beefalo?",
            "Let's stay still and see what it does.",
        },
        BABYOX = {
            "Look, the baby water beefalo has noticed us.",
            "I won't stand between it and its way home.",
        },
        OX_HORN = {
            "I'll keep the horn apart from the food in my pack.",
            "I'll need this if I decide to make the dripple pipes.",
        },
        OXHAT = {
            "Would the horned helmet leave any room for my glasses?",
            "I'd take a look in a mirror before going out.",
        },
        OX_FLUTE = {
            "I'd like to show the dripple pipes to someone back at camp.",
            "I remember setting aside the nightmare fuel to make this.",
        },
        MOSQUITO_POISON = {
            "I should ask what dose of the poison mosquito is safe.",
            "I'll keep it away from the cooking things.",
        },
        MOSQUITOSACK_YELLOW = {
            "I'd set the yellow mosquito sack beside the rest of my supplies.",
            "I wonder how long it's been here.",
        },
        STUNGRAY = {
            "I'd like to watch the stink ray from somewhere quiet.",
            "Let's stay still and see what it does.",
        },
        POISONHOLE = {
            "I'd like to see the poisonous hole by daylight before we go farther.",
            "Let's keep the way back in sight.",
        },
        GASHAT = {
            "Would the particulate purifier leave any room for my glasses?",
            "I'll have to set aside the empty bottle if I make another.",
        },
        ANTIVENOM = {
            "I'd label the anti venom before I put it with the supplies.",
            "I'll have to set aside the venom gland if I make another.",
        },
        VENOMGLAND = {
            "I'd like to show the venom gland to someone back at camp.",
            "I'll need this if I decide to make the anti venom.",
        },
        POISONBALM = {
            "I should ask what dose of the poison balm is safe.",
            "I'll keep it away from the cooking things.",
        },
        SPEAR_POISON = {
            "The poison spear takes a different grip from my katana.",
            "I'll keep it dry on the walk back.",
        },
        BLOWDART_POISON = {
            "I'll put a cover over the point before I carry it.",
            "The shaft is so light I can barely feel it in my sleeve.",
        },
        SHARX = {
            "Look, the sea hound has noticed us.",
            "I can tell more by watching than by chasing it.",
        },
        SHARK_FIN = {
            "I'd set a little of the shark fin aside for our guest.",
            "I'll need this if I decide to make the sleek hat.",
        },
        SHARKFINSOUP = {
            "I wonder if Warly would season the shark fin soup differently.",
            "I'll get the plates out.",
        },
        SHARK_TEETHHAT = {
            "I should tuck my fringe back before trying on the shark tooth crown.",
            "I can see where the hound's tooth went into it.",
        },
        AERODYNAMICHAT = {
            "I should tuck my fringe back before trying on the sleek hat.",
            "I remember setting aside the shark fin to make this.",
        },
        IA_MESSAGEBOTTLE = {
            "I want a quiet moment to look over the message in a bottle.",
            "The writing's easier to see in daylight.",
        },
        IA_MESSAGEBOTTLEEMPTY = {
            "I want a quiet moment to look over the empty bottle.",
            "The writing's easier to see in daylight.",
        },
        BURIEDTREASURE = {
            "I'd like to see the x marks the spot in daylight.",
            "I should make a quick sketch before we leave.",
        },
        SAND = {
            "I'd set the sand beside the rest of my supplies.",
            "I should save some for the empty bottle.",
        },
        SANDDUNE = {
            "I ought to remember the way back to the sandy pile.",
            "Somebody at camp might know its story.",
        },
        SANDBAGSMALL = {
            "With it here, the camp would have a proper boundary.",
            "We'll want an opening wide enough for our beefalo.",
        },
        SANDBAGSMALL_ITEM = {
            "I'll check the alignment of it against the next section.",
            "We'll want an opening wide enough for our beefalo.",
        },
        SANDCASTLE = {
            SAND = {
                "Each little tower has been pressed into shape.",
                "I hope the tide leaves it standing a while.",
            },
            GENERIC = {
                "I ought to remember the way back to the sand castle.",
                "I can see where the palm leaf went into it.",
            },
        },
        SUPERTELESCOPE = {
            "I'd like to show the super spyglass to someone back at camp.",
            "I'll have to set aside the eye of the tiger shark if I make another.",
        },
        TELESCOPE = {
            "I'd like to show the spyglass to someone back at camp.",
            "That reminds me, we could make the super spyglass with some of this.",
        },
        DOYDOY = {
            "Look, the doydoy has noticed us.",
            "I can tell more by watching than by chasing it.",
        },
        DOYDOYBABY = {
            "I should mind my boots near those tiny feet.",
            "Come along, little bird. That's no place to wander.",
        },
        DOYDOYEGG = {
            "I wouldn't risk dropping the doydoy egg on the way back.",
            "The shell's thinner than it looks.",
        },
        DOYDOYEGG_CRACKED = {
            "I wouldn't risk dropping it on the way back.",
            "The shell's thinner than it looks.",
        },
        DOYDOYFEATHER = {
            "I can see every fine strand on the doydoy feather.",
            "So much colour in something that weighs so little.",
        },
        DOYDOYNEST = {
            "I'd approach the doydoy nest quietly enough to hear who's in there.",
            "I'll leave the entrance clear.",
        },
        TROPICALFAN = {
            "I want to see how they put the tropical fan together.",
            "I'm better with a blade than a set of gears.",
        },
        PALMTREE = {
            BURNING = {
                "The fire's spreading over the palm tree!",
                "Has anyone brought water?",
            },
            BURNT = {
                "I won't get any more use out of the palm tree.",
                "I'll see what survived nearby.",
            },
            CHOPPED = {
                "That's a fresh cut on the palm tree.",
                "I'll leave room for a new tree.",
            },
            GENERIC = {
                "I'll remember where the palm tree grows.",
                "I could come back tomorrow to see what has changed.",
            },
        },
        COCONUT = {
            "I'd save the coconut for after practice.",
            "That reminds me, we could make the sleek hat with some of this.",
        },
        COCONUT_HALVED = {
            "Two neat halves. Shall we share?",
            "I can scrape the white flesh out with a spoon.",
        },
        COCONUT_COOKED = {
            "I could smell the roasted coconut before I saw it.",
            "Hot food is worth the wait.",
        },
        COCONUT_SAPLING = {
            "I know a patch of soil for the palm tree sapling.",
            "I'd better find a place where no one will tread on it.",
        },
        PALMLEAF = {
            "I hope there's enough of the palm leaf to share.",
            "That reminds me, we could make the sand castle with some of this.",
        },
        PALMLEAF_UMBRELLA = {
            "I'd set the palm leaf umbrella beside the rest of my supplies.",
            "I'll have to set aside the twigs if I make another.",
        },
        PALMLEAF_HUT = {
            "I'd approach the palm leaf hut quietly enough to hear who's in there.",
            "I remember setting aside the palm leaf to make this.",
        },
        LEIF_PALM = {
            "That tree just turned to face me.",
            "I'll put the axe away and back off slowly.",
        },
        CRAB = {
            GENERIC = {
                "I can see the crabbit through the water.",
                "I'll stay still until the surface clears.",
            },
            HIDDEN = {
                "I can just tell where the crabbit is hiding.",
                "There's movement under the surface.",
            },
        },
        CRABHOLE = {
            "I'd like to see the crabbit den by daylight before we go farther.",
            "Better check the footing near the edge.",
        },
        TRAWLNETDROPPED = {
            SOON = {
                "Grab the net before it slips below the surface.",
                "I can still see the floats from here.",
            },
            SOONISH = {
                "Grab the net before it slips below the surface.",
                "I can still see the floats from here.",
            },
            GENERIC = {
                "Grab the net before it slips below the surface.",
                "I can still see the floats from here.",
            },
        },
        TRAWLNET = {
            "I'd like to show the trawl net to someone back at camp.",
            "I remember setting aside the rope to make this.",
        },
        IA_TRIDENT = {
            "I'd put the trident within reach when I pack.",
            "A dry handle makes all the difference.",
        },
        KRAKEN = {
            "Is that the usual gait for the quacken?",
            "I won't stand between it and its way home.",
        },
        KRAKENCHEST = {
            "I ought to check what's already in the chest of the depths.",
            "It pays to know where you put the spare supplies.",
        },
        KRAKEN_TENTACLE = {
            "I'd give the quacken tentacle a little room to pass.",
            "Let's stay still and see what it does.",
        },
        QUACKENBEAK = {
            "I hadn't expected to find the quacken beak out here.",
            "I'll need this if I decide to make the quacken drill.",
        },
        QUACKENDRILL = {
            "I ought to make a place for the quacken drill in my pack.",
            "I can see where the quacken beak went into it.",
        },
        QUACKERINGRAM = {
            "I'd bring the quackering ram back for a closer look.",
            "I'll have to set aside the bamboo if I make another.",
        },
        MAGMAROCK = {
            "I'd like a closer look at the surface of the magma pile.",
            "I should look for a natural crack first.",
        },
        MAGMAROCK_GOLD = {
            "I can feel the weight of the magma pile just looking at it.",
            "The colour changes where the surface has worn away.",
        },
        FLAMEGEYSER = {
            "I ought to remember the route back from the krissure.",
            "Let's keep the way back in sight.",
        },
        TELEPORTATO_SW_RING = {
            "I can see how this would join another part.",
            "I'll sketch the fitting before I go looking for the rest.",
        },
        TELEPORTATO_SW_BOX = {
            "I can see how this would join another part.",
            "I'll sketch the fitting before I go looking for the rest.",
        },
        TELEPORTATO_SW_CRANK = {
            "I can see how this would join another part.",
            "I'll sketch the fitting before I go looking for the rest.",
        },
        TELEPORTATO_SW_POTATO = {
            "I can see how this would join another part.",
            "I'll sketch the fitting before I go looking for the rest.",
        },
        TELEPORTATO_SW_BASE = {
            "I can see how this would join another part.",
            "I'll sketch the fitting before I go looking for the rest.",
        },
        PRIMEAPE = {
            "I'd give the prime ape a little room to pass.",
            "I won't stand between it and its way home.",
        },
        PRIMEAPEBARREL = {
            "I'd like to see the prime ape hut in daylight.",
            "I'll have to set aside the twigs if I make another.",
        },
        MONKEYBALL = {
            "I can just make out the silly monkey ball from here.",
            "I'll have to set aside the snakeskin if I make another.",
        },
        WILBUR_UNLOCK = {
            "Good day to you, Your Majesty. Or is that a little premature?",
            "What a dignified little monkey.",
        },
        WILBUR_CROWN = {
            "Let me try it with my hair tied back.",
            "I like to keep my line of sight clear.",
        },
        MERMFISHER = {
            "Look, the fishermerm has noticed us.",
            "I won't stand between it and its way home.",
        },
        MERMHOUSE_FISHER = {
            "I'd approach the fishermerm's hut quietly enough to hear who's in there.",
            "I'll leave the entrance clear.",
        },
        OCTOPUSKING = {
            "I wonder what the yaarctopus looked like when this place was new.",
            "I can see a little more from the other side.",
        },
        OCTOPUSCHEST = {
            "I ought to check what's already in the octo chest.",
            "It pays to know where you put the spare supplies.",
        },
        SWEET_POTATO = {
            "I could make room for the sweet potato at supper.",
            "I'd set a serving aside for the late watch.",
        },
        SWEET_POTATO_COOKED = {
            "I should let the cooked sweet potato cool before I take a bite.",
            "Hot food is worth the wait.",
        },
        SWEET_POTATO_PLANTED = {
            "I'd remember where that patch grows.",
            "I want to see how it grows in this soil.",
        },
        SWEET_POTATO_SEEDS = {
            "I keep the stellar seeds in a dry pocket.",
            "I'll keep a few back for a second sowing.",
        },
        SWEET_POTATO_OVERSIZED = {
            "I'd like to weigh the giant sweet potato before we cut it.",
            "I'll need more than my usual basket.",
        },
        SWEETPOTATOSOUFFLE = {
            "I'd save a serving of the sweet potato souffle for the person who cooked.",
            "This is worth getting a clean plate for.",
        },
        BOAT_WOODLEGS = {
            "I wonder what a heavy swell would do to the \"sea legs\".",
            "Someone keep an eye on the current while I do this.",
        },
        WOODLEGSHAT = {
            "Would the lucky hat leave any room for my glasses?",
            "I like to keep my line of sight clear.",
        },
        SAIL_WOODLEGS = {
            "I'll check it before we leave the shore.",
            "It's easier to sort things out here than in rough seas.",
        },
        PEG_LEG = {
            "Someone shaped this to take a person's weight.",
            "I'd want to smooth every splinter off before using it.",
        },
        PIRATEGHOST = {
            "I'll mark the spot where we found the pirate ghost.",
            "I want to know why it's here in this particular spot.",
        },
        WILDBORE = {
            "I'd like to watch the wildbore from somewhere quiet.",
            "Let's stay still and see what it does.",
        },
        WILDBOREHEAD = {
            "I'll mark the spot where we found the wildbore head.",
            "Next time I'll bring my notebook.",
        },
        WILDBOREHOUSE = {
            "I'd approach the wildbore house quietly enough to hear who's in there.",
            "I'll leave the entrance clear.",
        },
        MANGROVETREE = {
            "I'll remember where the mangrove grows.",
            "I could come back tomorrow to see what has changed.",
        },
        MANGROVETREE_BURNT = {
            "I'd like a drawing of it for my notes.",
            "I should mind where I step near the roots.",
        },
        PORTAL_SHIPWRECKED = {
            "I ought to remember the route back from it.",
            "Let's keep the way back in sight.",
        },
        SHIPWRECKED_ENTRANCE = {
            "I'll mark it on my map.",
            "I'll make a note of the nearest shelter.",
        },
        SHIPWRECKED_EXIT = {
            "I'll mark it on my map.",
            "I'll make a note of the nearest shelter.",
        },
        TIDALPOOL = {
            "I'll mark the tidal pool on my map.",
            "Better check the footing near the edge.",
        },
        FISHINHOLE = {
            "I'll mark the shoal on my map.",
            "I'll make a note of the nearest shelter.",
        },
        FISH_TROPICAL = {
            "The colours on the tropical fish are even brighter in the water.",
            "I could watch those fins turn in the light all afternoon.",
        },
        TIDAL_PLANT = {
            "I want to look at it in better light.",
            "I could come back tomorrow to see what has changed.",
        },
        MARSH_PLANT_TROPICAL = {
            "I'll leave a marker by these leaves.",
            "I'll take a closer look without pulling at the roots.",
        },
        FLUP = {
            "Look, the flup has noticed us.",
            "Let's stay still and see what it does.",
        },
        BLOWDART_FLUP = {
            "I'll put a cover over the point before I carry it.",
            "The shaft is so light I can barely feel it in my sleeve.",
        },
        SEA_LAB = {
            "I'll mark the spot where we found the sea lab.",
            "I remember setting aside the sand to make this.",
        },
        BUOY = {
            "We'll be able to find our way back by the buoy.",
            "I can see where the empty bottle went into it.",
        },
        WATERCHEST = {
            "Takina would make a list of everything in the sea chest.",
            "I'd like one place where my glasses won't get crushed.",
        },
        LUGGAGECHEST = {
            "I'd put the things I don't need yet in the steamer trunk.",
            "I'll keep the things we need first near the top.",
        },
        WATERYGRAVE = {
            "I'd like to see the watery grave in daylight.",
            "I can see a little more from the other side.",
        },
        SHIPWRECK = {
            "I wonder what the wreck looked like when this place was new.",
            "Somebody at camp might know its story.",
        },
        BARREL_GUNPOWDER = {
            "I'd stop by the gunpowder barrel again when we have more time.",
            "I'll walk round it once for a better look.",
        },
        RAWLING = {
            "I'd like to show the rawling to someone back at camp.",
            "I'll turn it over and have a look at the other side.",
        },
        GRASS_WATER = {
            "A little ripple gave the grass away.",
            "The light changes so much beneath the waves.",
        },
        KNIGHTBOAT = {
            "Is that the usual gait for the floaty boaty knight?",
            "I can tell more by watching than by chasing it.",
        },
        DEPLETED_BAMBOOTREE = {
            "I'll remember where it grows.",
            "I could come back tomorrow to see what has changed.",
        },
        DEPLETED_BUSH_VINE = {
            "I want to look at it in better light.",
            "I'd leave room for new growth.",
        },
        DEPLETED_GRASS_WATER = {
            "A little ripple gave it away.",
            "The light changes so much beneath the waves.",
        },
        WALLYINTRO_DEBRIS = {
            "With the debris here, the camp would have a proper boundary.",
            "I'll look along the top to see if it's straight.",
        },
        BOOK_METEOR = {
            "I want to see the first page of “Joy of Volcanology”.",
            "I won't read it aloud until I know what it does.",
        },
        CRATE = {
            "I'll mark the spot where we found the crate.",
            "I'll walk round it once for a better look.",
        },
        SPEAR_LAUNCHER = {
            "I'd like to feel the balance of the speargun.",
            "My teacher always checked the fittings first.",
        },
        MUTATOR_TROPICAL_SPIDER_WARRIOR = {
            "I'll leave the tropical switcherdoodle with Webber and his little friends.",
            "I should label that before anyone mistakes it for a snack.",
        },
        BOAT_SURFBOARD = {
            "I wonder what a heavy swell would do to the surfboard.",
            "It's easier to sort things out here than in rough seas.",
        },
        SURFBOARD_ITEM = {
            "There's enough ground here for the surfboard, I think.",
            "Better check the ground is level first.",
        },
        WALANI = {
            GENERIC = {
                "How are the waves today, %s?",
                "%s, shall we take the boards out before supper?",
            },
            ATTACKER = {
                "%s, easy, friend. Shall we talk this through?",
                "%s, put your hands down. I'm listening.",
            },
            MURDERER = {
                "Stand back. I've seen what you've done.",
                "Nobody else is getting hurt here.",
            },
            REVIVER = {
                "%s, you took care of our friend. I won't forget it.",
                "%s, thank you for going back when someone needed help.",
            },
            GHOST = {
                "%s, stay close. I'll see what I can do about a heart.",
                "%s, we came here together. We're leaving together.",
            },
            FIRESTARTER = {
                "%s, please watch where those sparks land.",
                "%s, keep the fire away from everyone's things.",
            },
        },
        WILBUR = {
            GENERIC = {
                "A bow for His Majesty, %s.",
                "I hope your crossing was calm, %s.",
            },
            ATTACKER = {
                "%s, easy, friend. Shall we talk this through?",
                "%s, put your hands down. I'm listening.",
            },
            MURDERER = {
                "Stand back. I've seen what you've done.",
                "Nobody else is getting hurt here.",
            },
            REVIVER = {
                "%s, you took care of our friend. I won't forget it.",
                "%s, thank you for going back when someone needed help.",
            },
            GHOST = {
                "%s, stay close. I'll see what I can do about a heart.",
                "%s, we came here together. We're leaving together.",
            },
            FIRESTARTER = {
                "%s, please watch where those sparks land.",
                "%s, keep the fire away from everyone's things.",
            },
        },
        WOODLEGS = {
            GENERIC = {
                "Any news from the sea, %s?",
                "I'd like to hear about your last voyage, %s.",
            },
            ATTACKER = {
                "%s, easy, friend. Shall we talk this through?",
                "%s, put your hands down. I'm listening.",
            },
            MURDERER = {
                "Stand back. I've seen what you've done.",
                "Nobody else is getting hurt here.",
            },
            REVIVER = {
                "%s, you took care of our friend. I won't forget it.",
                "%s, thank you for going back when someone needed help.",
            },
            GHOST = {
                "%s, stay close. I'll see what I can do about a heart.",
                "%s, we came here together. We're leaving together.",
            },
            FIRESTARTER = {
                "%s, please watch where those sparks land.",
                "%s, keep the fire away from everyone's things.",
            },
        },
    },
}
