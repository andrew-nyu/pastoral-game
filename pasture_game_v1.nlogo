extensions [bitmap]

breed [pastures pasture]
breed [borders border]
breed [animals animal]
breed [scorecards scorecard]
breed [blocks block]
breed [phaseMarkers phaseMarker]
breed [currentMarkers currentMarker]

pastures-own [sizePasture neighborList]
patches-own [inGame pastureNumber pastureGrowth]
animals-own [owner usingPasture age cumulativeNeed cumulativeGrass state]
scorecards-own [identity playerNumber]
blocks-own [identity playerNumber]
phaseMarkers-own [identity]
currentMarkers-own [identity]

globals [
  numPlayers
  playerHHID
  playerConfirm
  playerShortNames
  playerNames
  playerPosition 
  playerHerds
  playerCalves
  playerScores
  playerInsuredAnimals
  playerTempHerds
  playerTempScores
  playerTempCalves
  playerTempInsuredAnimals
  playerTempFodder
  playerTempSoldAnimals
  playerHerdOnBoard
  playerHerdColor
  pastureColor
  numPastures 
  messageAddressed
  parameterHandled
  gameInProgress
  langSuffix
  numPatches
  initialHerdSize
  phasePasture
  phaseInsure
  phaseFodder
  phaseAnimal
  grassPhaseList
  pastGrassList
  currentYear 
  currentPhase
  showingGameInformation
  
  ;;visualization parameters and variables
  pointsPixLoc
  insuredPixLoc
  fodderPixLoc
  buyAnimalsPixLoc
  sellAnimalsPixLoc
  herdPixLoc
  calvesPixLoc
  yearPixLoc
  phasePixLoc
  pointsTile
  insuredTile
  fodderTile
  buyAnimalsTile
  sellAnimalsTile
  herdTile  
  calvesTile
  yearTile
  phaseTile
  insuredAnimalsTile
  insuredAnimalsPixLoc
  insuredPlusPixLoc
  insuredMinusPixLoc
  fodderPlusPixLoc
  fodderMinusPixLoc
  buyAnimalsPlusPixLoc
  buyAnimalsMinusPixLoc
  sellAnimalsPlusPixLoc
  sellAnimalsMinusPixLoc
  insuredPlusTile
  insuredMinusTile
  fodderPlusTile
  fodderMinusTile
  buyAnimalsPlusTile
  buyAnimalsMinusTile
  sellAnimalsPlusTile
  sellAnimalsMinusTile
  confirmPixLoc
  confirmTile
  colorList
  patchesPerInfoLine
  rgb_R
  rgb_G
  rgb_B
  insurancePhaseRemaining
  
  ;;variables related to parsing parameter input
  inputFileLabels
  completedGamesIDs
  parsedInput
  currentSessionParameters
  gameTag
  
  ;;parameters to be set by input file
  numYears
  numPhases
  gameName
  saleValuePoor
  saleValueOk
  saleValueGood
  saleValueCalf
  keepValuePoor
  keepValueOk
  keepValueGood
  keepValueCalf
  buyCalfCost
  insureCost
  fodderCostOneStep
  phaseLengthDays
  initialScore
  phasesCalf
  probDeathPoor
  probDeathOk
  probDeathGood
  grassR
  grassK
  grassE0
  calfNeeds
  animalNeeds
  downThreshold
  upThreshold
  grassUndergroundFraction
  insureTrigger
  insurePayout
  insurePeriod
  ]

to start-hubnet
  
  ;; clean the slate
  clear-all
  hubnet-reset
  
  ;; set all session variables that are preserved across games
  set playerNames (list)
  set playerShortNames (list)
  set playerHHID (list)
  set playerPosition (list)
  set playerHerdColor (list)
  set numPlayers 0
  set gameInProgress 0
  set-default-shape animals "sheep 2"
  set-default-shape scorecards "blank"
  set-default-shape blocks "square"
  set-default-shape phaseMarkers "square"
  set-default-shape currentMarkers "square outline"
  
  set patchesPerInfoLine 5
  set rgb_G 100
  set rgb_B 0
  set rgb_R 150
  set colorList (list 95 15 25 115 125 5 135 93 13 23 113 123 3 133 98 18 28 118 128 8 138)  ;; add to this if you will have more than 21 players, but really, you shouldn't!!!
  
  ;; clear anything from the display, just in case
  clear-ticks
  clear-patches
  clear-turtles
  clear-drawing
  
  ;; try to read in the input parameter data - stop if the file doesn't exist
  if not file-exists? inputParameterFileName [ ;;if game parameter file is incorrect
    user-message "Please enter valid file name for input data"
    stop
  ]
  
  ;; open the file and read it in line by line
  file-open inputParameterFileName
  let fullDataList []
  let foundEndLabel 0
  let lengthList 0
  while [not file-at-end?] [
    let tempValue file-read
    if (not is-string? tempValue and foundEndLabel = 0) [set foundEndLabel 1 set lengthList length fullDataList]
    set fullDataList lput tempValue fullDataList 
  ] 
  set inputFileLabels sublist fullDataList 0 lengthList
  set fullDataList sublist fullDataList lengthList length fullDataList
  file-close
  
  ;; look in the list of completed game IDs, and take an initial guess that the session of interest is one higher than the highest session completed previously
  set completedGamesIDs []
  ifelse file-exists? "completedGames.csv" [
  file-open "completedGames.csv"
  while [not file-at-end?] [
    let tempValue file-read-line
    set completedGamesIDs lput read-from-string substring tempValue 0 position "_" tempValue completedGamesIDs
  ] 
  set completedGamesIDs remove-duplicates completedGamesIDs
  set sessionID max completedGamesIDs + 1
  file-close
  ] [
  set sessionID -9999
  ]
  
  ;; parse the input into a list of game variable labels and values
  set parsedInput [[]]
  let currentID 0
  while [length fullDataList > 0] [
    let currentSubList sublist fullDataList 0 lengthList
    set fullDataList sublist fullDataList lengthList length fullDataList
    
    if (item 0 currentSubList != currentID) [set currentID item 0 currentSubList set parsedInput lput [] parsedInput]
    set parsedInput replace-item currentID parsedInput (lput currentSubList item currentID parsedInput)
  ]

  set currentSessionParameters []

end

to initialize-session
  
  ;; stop if we are currently in a session
  if (length currentSessionParameters > 0) 
  [user-message "Current session is not complete.  Please continue current session.  Otherwise, to start new session, please first clear settings by clicking 'Launch Broadcast'"
    stop]
  
  ;; if the session requested isn't in our input parameters, stop
  if (sessionID > length parsedInput or sessionID < 1)
  [user-message "Session ID not found in input records"
    stop]
  
  ;; if the session requested has prior game data available, let the user know
  if (member? sessionID completedGamesIDs)
  [user-message "Warning: At least one game file with this sessionID has been found"]
  
  ;; pick the appropriate set of parameters for the current session from the previously parsed input file
  set currentSessionParameters item sessionID parsedInput
  
end

to set-game-parameters
  
  ;; this procedure takes the list of parameters names and values and processes them for use in the current game
  
  ;; take the current game's set of parameters
  let currentGameParameters item 0 currentSessionParameters
  set currentSessionParameters sublist currentSessionParameters 1 length currentSessionParameters
  
  ;; there are two lists - one with variable names, one with values
  (foreach inputFileLabels currentGameParameters [ ;; first element is variable name, second element is value
      
      ;; we use a 'parameter handled' structure to avoid having nested foreach statements
      set parameterHandled 0
      
      ;; if it's the game id, set the game tag as being a practice (if it's 0) or game number otherwise
      if ?1 = "gameID" and parameterHandled = 0[
        ifelse ?2 = 0 [ set gameTag "GP" output-print (word "Game: GP") file-print (word "Game: GP")] [ set gameTag (word "G" ?2) output-print (word "Game: G" ?2) file-print (word "Game: G" ?2)] 
        output-print " "
        output-print " "
        output-print "Relevant Game Parameters:"
        output-print " "
        file-print (word ?1 ": " ?2 )
        set parameterHandled 1
      ] 
      
      ;; add any particular cases for parameter handling here
      
      ;; if there is a list of phase structures, read in as below
      if substring ?1 0 6 = "phase_" [
        let phaseNumber read-from-string substring ?1 6 (length ?1)
        let numPhasesSoFar length phasePasture
        while [numPhasesSoFar < phaseNumber] [
          set phasePasture lput 0 phasePasture
          set phaseInsure lput 0 phaseInsure
          set phaseFodder lput 0 phaseFodder
          set phaseAnimal lput 0 phaseAnimal
          set numPhasesSoFar numPhasesSoFar + 1
        ]
        let currentString ?2
        while [length currentString > 0] [
          ifelse first currentString = "P" [
            set phasePasture replace-item (phaseNumber - 1) phasePasture 1
          ] [
          ifelse first currentString = "I" [
            set phaseInsure replace-item (phaseNumber - 1) phaseInsure 1
          ]  [
          ifelse first currentString = "F" [
            set phaseFodder replace-item (phaseNumber - 1) phaseFodder 1
          ] [
          if first currentString = "A" [
            set phaseAnimal replace-item (phaseNumber - 1) phaseAnimal 1
          ]
          ]
          ]
          ]
          set currentString but-first currentString
          ]
       file-print (word ?1 ": " ?2 )
       set parameterHandled 1
      ]
   
      ;; if there is a list of grass growth (i.e., evapotranspiration) structures, read in as below
      if substring ?1 0 6 = "grass_" [
        let grassNumber read-from-string substring ?1 6 (length ?1)
        let numGrassSoFar length grassPhaseList
        while [numGrassSoFar < grassNumber] [
          set grassPhaseList lput 0 grassPhaseList
          set numGrassSoFar numGrassSoFar + 1
        ]
        set grassPhaseList replace-item (grassNumber - 1) grassPhaseList ?2

       ;; set parameter handled
       file-print (word ?1 ": " ?2 )
       set parameterHandled 1
      ]
      
      ;; all other cases not specified above are handled as below - the parameter of the same name is set to the specified value   
      if parameterHandled = 0 [  ;; any other case
        output-print (word ?1 ": " ?2 )
        file-print (word ?1 ": " ?2 )
        run(word "set " ?1 " " ?2 )
      ]
  ])
  file-print ""
  
end

to set-language
  
  if language = "English" [ set langSuffix "en"]  
  
  ;;LOAD IN THE LANGUAGE TILES BASED ON LANGUAGE SELECTION
  
  ;;The following code fixes the locations and sizes of the in-game text.  It was optimized to an 50 x 50 box with a patch size of 14 pixels, for use with a Dell Venue 8 as a client.
  ;;The structure of the location variables is [xmin ymin width height].  They have been 'converted' to scale with a changing patch size and world size, but this is not widely tested
  let yConvertPatch (numPatches / 50)  ;;scaling vertical measures based on the currently optimized size of 50
  let xyConvertPatchPixel (patch-size / 14)  ;; scaling vertical and horizontal measures based on currently optimized patch size of 14
  
  set pointsPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (20 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set pointsTile bitmap:import (word "./image_label/points_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled pointsTile (item 2 pointsPixLoc) (item 3 pointsPixLoc)) (item 0 pointsPixLoc) (item 1 pointsPixLoc)
  
  set insuredPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (100 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set insuredTile bitmap:import (word "./image_label/insured_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled insuredTile (item 2 insuredPixLoc) (item 3 insuredPixLoc)) (item 0 insuredPixLoc) (item 1 insuredPixLoc)
  
  set fodderPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set fodderTile bitmap:import (word "./image_label/fodder_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled fodderTile (item 2 fodderPixLoc) (item 3 fodderPixLoc)) (item 0 fodderPixLoc) (item 1 fodderPixLoc)
  
  set buyAnimalsPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (200 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set buyAnimalsTile bitmap:import (word "./image_label/buy_animals_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled buyAnimalsTile (item 2 buyAnimalsPixLoc) (item 3 buyAnimalsPixLoc)) (item 0 buyAnimalsPixLoc) (item 1 buyAnimalsPixLoc)
  
  set sellAnimalsPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (250 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set sellAnimalsTile bitmap:import (word "./image_label/sell_animals_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled sellAnimalsTile (item 2 sellAnimalsPixLoc) (item 3 sellAnimalsPixLoc)) (item 0 sellAnimalsPixLoc) (item 1 sellAnimalsPixLoc)
  
  set herdPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (390 * yConvertPatch * xyConvertPatchPixel) (75 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set herdTile bitmap:import (word "./image_label/herd_state_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled herdTile (item 2 herdPixLoc) (item 3 herdPixLoc)) (item 0 herdPixLoc) (item 1 herdPixLoc)
   
  set calvesPixLoc (list (20 * yConvertPatch * xyConvertPatchPixel) (310 * yConvertPatch * xyConvertPatchPixel) (75 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set calvesTile bitmap:import (word "./image_label/calves_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled calvesTile (item 2 calvesPixLoc) (item 3 calvesPixLoc)) (item 0 calvesPixLoc) (item 1 calvesPixLoc)
    
  set insuredAnimalsPixLoc (list (200 * yConvertPatch * xyConvertPatchPixel) (310 * yConvertPatch * xyConvertPatchPixel) (100 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set insuredAnimalsTile bitmap:import (word "./image_label/insured_animals_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled insuredAnimalsTile (item 2 insuredAnimalsPixLoc) (item 3 insuredAnimalsPixLoc)) (item 0 insuredAnimalsPixLoc) (item 1 insuredAnimalsPixLoc)
  
  set insuredPlusPixLoc (list (280 * yConvertPatch * xyConvertPatchPixel) (100 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set insuredPlusTile bitmap:import (word "./image_label/plus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled insuredPlusTile (item 2 insuredPlusPixLoc) (item 3 insuredPlusPixLoc)) (item 0 insuredPlusPixLoc) (item 1 insuredPlusPixLoc)
  
  set fodderPlusPixLoc (list (280 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set fodderPlusTile bitmap:import (word "./image_label/plus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled fodderPlusTile (item 2 fodderPlusPixLoc) (item 3 fodderPlusPixLoc)) (item 0 fodderPlusPixLoc) (item 1 fodderPlusPixLoc)
  
  set buyAnimalsPlusPixLoc (list (280 * yConvertPatch * xyConvertPatchPixel) (200 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set buyAnimalsPlusTile bitmap:import (word "./image_label/plus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled buyAnimalsPlusTile (item 2 buyAnimalsPlusPixLoc) (item 3 buyAnimalsPlusPixLoc)) (item 0 buyAnimalsPlusPixLoc) (item 1 buyAnimalsPlusPixLoc)
  
  set sellAnimalsPlusPixLoc (list (280 * yConvertPatch * xyConvertPatchPixel) (250 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set sellAnimalsPlusTile bitmap:import (word "./image_label/plus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled sellAnimalsPlusTile (item 2 sellAnimalsPlusPixLoc) (item 3 sellAnimalsPlusPixLoc)) (item 0 sellAnimalsPlusPixLoc) (item 1 sellAnimalsPlusPixLoc)

  set insuredMinusPixLoc (list (340 * yConvertPatch * xyConvertPatchPixel) (100 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set insuredMinusTile bitmap:import (word "./image_label/minus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled insuredMinusTile (item 2 insuredMinusPixLoc) (item 3 insuredMinusPixLoc)) (item 0 insuredMinusPixLoc) (item 1 insuredMinusPixLoc)
  
  set fodderMinusPixLoc (list (340 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set fodderMinusTile bitmap:import (word "./image_label/minus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled fodderMinusTile (item 2 fodderMinusPixLoc) (item 3 fodderMinusPixLoc)) (item 0 fodderMinusPixLoc) (item 1 fodderMinusPixLoc)
  
  set buyAnimalsMinusPixLoc (list (340 * yConvertPatch * xyConvertPatchPixel) (200 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set buyAnimalsMinusTile bitmap:import (word "./image_label/minus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled buyAnimalsMinusTile (item 2 buyAnimalsMinusPixLoc) (item 3 buyAnimalsMinusPixLoc)) (item 0 buyAnimalsMinusPixLoc) (item 1 buyAnimalsMinusPixLoc)
  
  set sellAnimalsMinusPixLoc (list (340 * yConvertPatch * xyConvertPatchPixel) (250 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set sellAnimalsMinusTile bitmap:import (word "./image_label/minus_active" ".png")
  bitmap:copy-to-drawing (bitmap:scaled sellAnimalsMinusTile (item 2 sellAnimalsMinusPixLoc) (item 3 sellAnimalsMinusPixLoc)) (item 0 sellAnimalsMinusPixLoc) (item 1 sellAnimalsMinusPixLoc)  
  
  set confirmPixLoc (list (250 * yConvertPatch * xyConvertPatchPixel) (500 * yConvertPatch * xyConvertPatchPixel) (150 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set confirmTile bitmap:import (word "./image_label/confirm_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled confirmTile (item 2 confirmPixLoc) (item 3 confirmPixLoc)) (item 0 confirmPixLoc) (item 1 confirmPixLoc)
  
  set yearPixLoc (list (50 * yConvertPatch * xyConvertPatchPixel) (580 * yConvertPatch * xyConvertPatchPixel) (75 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set yearTile bitmap:import (word "./image_label/year_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled yearTile (item 2 yearPixLoc) (item 3 yearPixLoc)) (item 0 yearPixLoc) (item 1 yearPixLoc)
  
  set phasePixLoc (list (200 * yConvertPatch * xyConvertPatchPixel) (580 * yConvertPatch * xyConvertPatchPixel) (75 * yConvertPatch * xyConvertPatchPixel) (50 * yConvertPatch * xyConvertPatchPixel))
  set phaseTile bitmap:import (word "./image_label/phase_" langSuffix ".png")
  bitmap:copy-to-drawing (bitmap:scaled phaseTile (item 2 phasePixLoc) (item 3 phasePixLoc)) (item 0 phasePixLoc) (item 1 phasePixLoc)
  
end

to start-game
  
  ;; stop if a game is already running  
  if (gameInProgress = 1) 
  [user-message "Current game is not complete.  Please continue current game.  Otherwise, to start new session, please first clear settings by clicking 'Launch Broadcast'"
    stop]

  
  ;; stop if there are no more game parameters queued up
  if (length currentSessionParameters = 0)
  [user-message "No games left in session.  Re-initialize or choose new session ID"
    stop]
  
  
  ;; clear the output window and display
  clear-output
  clear-patches
  clear-turtles
  clear-drawing
  foreach playerPosition [
    hubnet-clear-overrides (item (? - 1) playerNames)
  ]
    
  ;;Set any parameters not set earlier, and not to be set from the read-in game file
  set showingGameInformation 0
  set-default-shape borders "line"
  set pastureColor [35 45 55]
  set phasePasture (list)
  set phaseInsure (list)
  set phaseFodder (list)
  set phaseAnimal (list)
  set grassPhaseList (list)
  set pastGrassList (list)

  ;; Start the game output file
  let tempDate date-and-time
  foreach [2 5 8 12 15 18 22] [set tempDate replace-item ? tempDate "_"]
  let playerNameList (word (item 0 playerNames) "_")
  foreach n-values (numPlayers - 1) [? + 1] [
   set playerNameList (word playerNameList "_" (item ? playerNames)) 
  ]
  set gameName (word sessionID "_" gameTag "_" playerNameList "_" tempDate ".csv" )
  carefully [file-delete gameName file-open gameName] [file-open gameName]

  ;; read in game file input
  set-game-parameters

  ;;trim and re-fit the game grass file if necessary
  set grassPhaseList filter [? >= 0] grassPhaseList
  let inputGrass grassPhaseList
  while [length grassPhaseList <= numYears * numPhases] [
    set grassPhaseList (sentence grassPhaseList inputGrass)
  ]

  ;;lay out the game board
  let pixelsPerPatch 800 / numPatches
  resize-world (- 480 / pixelsPerPatch) (numPatches - 1) 0 (numPatches - 1)
  set-patch-size pixelsPerPatch ;; optimized to a 1280 x 800 pixel screen
  
  ;; separate the pasture land from the display area, and seed the landscape
  ask patches [set pastureNumber -99
    ifelse (pxcor < 0) [
      set inGame 0
      set pcolor 0
      ][
      set inGame 1
      set pastureGrowth grassK
      let currentRGB_R (1 - (pastureGrowth / grassK)) * rgb_R
      let currentColor (list currentRGB_R rgb_G rgb_B)
      set pcolor currentColor ]
      ]
  
  ;; make pastures
  populate-landscape
  make-borders
  file-print "Pasture layout:"
  
  
  ;;initialize all of the list variables 
  set playerHerds (list)
  set playerHerdOnBoard (list)
  set playerCalves (list)
  set playerConfirm (list)
  set playerScores (list)
  set playerTempScores (list)
  set playerTempHerds (list)
  set playerTempCalves (list)
  set playerInsuredAnimals (list)
  set playerTempInsuredAnimals (list)
  set playerTempSoldAnimals (list)
  set playerTempFodder (list)
  foreach playerPosition [ ;; indexed from 1 to 4
    set playerHerds lput (list 0 initialHerdSize 0) playerHerds
    set playerTempHerds lput (list 0 0 0) playerTempHerds
    set playerTempSoldAnimals lput (list 0 0 0) playerTempSoldAnimals
    set playerHerdOnBoard lput 0 playerHerdOnBoard
    set playerCalves lput (n-values phasesCalf [0]) playerCalves
    set playerTempCalves lput (n-values phasesCalf [0]) playerTempCalves
    set playerConfirm lput 0 playerConfirm
    set playerInsuredAnimals lput 0 playerInsuredAnimals
    set playerTempInsuredAnimals lput 0 playerTempInsuredAnimals
    set playerScores lput initialScore playerScores
    set playerTempScores lput 0 playerTempScores
    set playerTempFodder lput (list 0 0 0) playerTempFodder
  ]
  
  ;;ADD IN ALL NECESSARY SCORING VARIABLES
  
  ;;The following code fixes the locations and sizes of the in-game text.  It was optimized to an 50 x 50 box with a patch size of 14 pixels, for use with a Dell Venue 8 as a client.
  ;;The structure of the location variables is [xmin ymin width height].  They have been 'converted' to scale with a changing patch size and world size, but this is not widely tested
  let yConvertPatch (numPatches / 50)  ;;scaling vertical measures based on the currently optimized size of 50
  let xyConvertPatchPixel (patch-size / 14)  ;; scaling vertical and horizontal measures based on currently optimized patch size of 14
  
  ;;lay out the agents that will provide score and other display information.  These too are optimized to a Dell Venue 8, with grid size 80x50, patch size 14, and may need adjustments if changes are made             
  create-scorecards 1 [setxy (-20 * yConvertPatch) (max-pycor - 28.5  * yConvertPatch) set label 0 set identity "poorHerd"]
  create-scorecards 1 [setxy (-12 * yConvertPatch) (max-pycor - 28.5  * yConvertPatch) set label 0 set identity "okHerd"]
  create-scorecards 1 [setxy (-4 * yConvertPatch) (max-pycor - 28.5  * yConvertPatch) set label 0 set identity "goodHerd"]  
  create-scorecards 1 [setxy (-20 * yConvertPatch) (max-pycor - 22.5  * yConvertPatch) set label 0 set identity "calves"] 
  create-scorecards 1 [setxy (-4 * yConvertPatch) (max-pycor - 22.5  * yConvertPatch) set label 0 set identity "insuredAnimals"] 
  create-scorecards 1 [setxy (-20 * yConvertPatch) (max-pycor - 41.5  * yConvertPatch) set label 0 set identity "year"] 
  create-scorecards 1 [setxy (-4 * yConvertPatch) (max-pycor - 41.5  * yConvertPatch) set label 0 set identity "phase"] 
  create-scorecards 1 [setxy (-4 * yConvertPatch) (max-pycor - 3  * yConvertPatch) set label 0 set identity "score" set label-color yellow] 
  create-scorecards 1 [setxy (-16 * yConvertPatch) (max-pycor - 11  * yConvertPatch) set label 0 set label-color red set identity "changeFodder"] 
  create-scorecards 1 [setxy (-16 * yConvertPatch) (max-pycor - 15  * yConvertPatch) set label 0 set label-color red set identity "changeCalves"] 
  create-scorecards 1 [setxy (-16 * yConvertPatch) (max-pycor - 19  * yConvertPatch) set label 0 set label-color red set identity "changeAnimals"] 
  create-scorecards 1 [setxy (12 * yConvertPatch) (max-pycor - 1 * yConvertPatch) set label "Player" set identity "inGameInformation" set hidden? true]
  create-scorecards 1 [setxy (25 * yConvertPatch) (max-pycor - 1 * yConvertPatch) set label "Points" set identity "inGameInformation" set hidden? true]
  create-scorecards 1 [setxy (43 * yConvertPatch) (max-pycor - 1 * yConvertPatch) set label "Animals" set identity "inGameInformation" set hidden? true]
  foreach playerPosition [
    create-scorecards 1 [setxy (11 * yConvertPatch) (max-pycor - (5 + ? * patchesPerInfoLine) * yConvertPatch) set label item (? - 1) playerShortNames set identity "inGameInformation" set hidden? true]
    create-scorecards 1 [setxy (24 * yConvertPatch) (max-pycor - (5 + ? * patchesPerInfoLine) * yConvertPatch) set label 0 set identity (word item (? - 1) playerNames "CurrentScore") set hidden? true]
    create-scorecards 1 [setxy (42 * yConvertPatch) (max-pycor - (5 + ? * patchesPerInfoLine) * yConvertPatch) set label 0 set identity (word item (? - 1) playerNames "FinalScore") set hidden? true]
  ]
       
  ;;make the blocks that cover over the buttons when they are unavailable to the current phase        
  foreach [-5 -7 -9 -11 -13 -15 -17 -19 -21 -23 -25 -27 -29] [
  create-blocks 1 [setxy (? * yConvertPatch) (max-pycor - 7.5  * yConvertPatch) set identity "insureBlock" set size 5 * yConvertPatch set color black] 
  ]
  foreach [-5 -7 -9 -11 -13 -15 -17 -19 -21 -23 -25 -27 -29] [
  create-blocks 1 [setxy (? * yConvertPatch) (max-pycor - 11.5  * yConvertPatch) set identity "fodderBlock" set size 5 * yConvertPatch set color black] 
  ]
  foreach [-5 -7 -9 -11 -13 -15 -17 -19 -21 -23 -25 -27 -29] [
  create-blocks 1 [setxy (? * yConvertPatch) (max-pycor - 15.5  * yConvertPatch) set identity "buyBlock" set size 5 * yConvertPatch set color black] 
  ] 
  foreach [-5 -7 -9 -11 -13 -15 -17 -19 -21 -23 -25 -27 -29] [
  create-blocks 1 [setxy (? * yConvertPatch) (max-pycor - 19.5  * yConvertPatch) set identity "sellBlock" set size 5 * yConvertPatch set color black] 
  ]
           
  ;;add phase markers at bottom left
  let sizePhaseMarker 25 / numPhases * yConvertPatch
  foreach n-values numPhases [?] [
    create-currentMarkers 1 [setxy ((-28 * yConvertPatch)  + (.1 + ?) * sizePhaseMarker)  ((2 * yConvertPatch) - (.1) * sizePhaseMarker) set identity (word "phase" (? + 1)) set size (.8 * sizePhaseMarker) set color gray]
    if item ? phasePasture = 1 [
      create-phaseMarkers 1 [setxy ((-28 * yConvertPatch) + ? * sizePhaseMarker)  2 * yConvertPatch set identity "pastureMarker" set size (0.2 * sizePhaseMarker) set color green]
    ]
    if item ? phaseInsure = 1 [
      create-phaseMarkers 1 [setxy ((-28 * yConvertPatch) + (0.2 + ?) * sizePhaseMarker)  2 * yConvertPatch set identity "insureMarker" set size (0.2 * sizePhaseMarker) set color blue]
    ]
    if item ? phaseFodder = 1 [
      create-phaseMarkers 1 [setxy ((-28 * yConvertPatch) + ? * sizePhaseMarker)  (2 * yConvertPatch - 0.2 * sizePhaseMarker) set identity "insureMarker" set size (0.2 * sizePhaseMarker) set color yellow]
    ]
    if item ? phaseAnimal = 1 [
      create-phaseMarkers 1 [setxy ((-28 * yConvertPatch) + (0.2 + ?) * sizePhaseMarker)  (2 * yConvertPatch - 0.2 * sizePhaseMarker) set identity "insureMarker" set size (0.2 * sizePhaseMarker) set color red]
    ]
  ]
  
  ;; get the game progress variables initialized
  set gameInProgress 1
  set currentYear 1
  set currentPhase 1
  ask currentMarkers with [identity = (word "phase" currentPhase)] [set color yellow]
  
  ;; set up the temp variables that manage the within-turn changes
  set playerTempHerds playerHerds
  set playerTempScores playerScores
  set playerTempCalves playerTempCalves
  set playerTempInsuredAnimals playerInsuredAnimals
  
  ;; update all players' screens, and add their animals (but don't place them anywhere yet!)
  foreach (playerPosition) [
    send-game-info (? - 1)
    let animalsToPlace sum (item (? - 1) playerHerds) + sum (item (? - 1) playerCalves)
    place-animals animalsToPlace ? -88
  ]
end


to populate-landscape
  
  ;; make pastures in the landscape
  create-pastures numPastures [ 
    set neighborList []
    setxy random-pxcor random-pycor
    while [(any? other pastures-here) or (pxcor < 0)] [setxy random-pxcor random-pycor]
    let currentPasture who
    ask patch-here [set pastureNumber currentPasture]
  ]
  
  ;; allocate patches to pastures
  while [any? patches with [pastureNumber < 0 and inGame = 1]] [
    ask patches with [pastureNumber < 0 and inGame = 1] [
      set pastureNumber [pastureNumber] of one-of neighbors4
    ]
    
  ]
  
  ;; count pasture size for pastures
  ask pastures [let currentPasture who
    set sizePasture count patches with [pastureNumber = currentPasture]    
    set hidden? true     
  ]
  
end

to make-borders
    ;; make border around pasture parcels
  ;; do this using 'border' agents that stamp an image of themselves between patches and then die
  ;; note:  if you have wraparound, the setxy line has to be modified to account for this
  
  ask patches [
    let currentOwner pastureNumber
    let x1 pxcor
    let y1 pycor
    ask neighbors4 [
      let x2 pxcor
      let y2 pycor
      let neighborOwner pastureNumber
     if neighborOwner != currentOwner [
       sprout-borders 1 [set color black 
         setxy mean (list x1 x2) mean (list y1 y2) 
         ifelse y1 != y2 [set heading 90] [set heading 0] 
         stamp die]
       
       if currentOwner > 0 [;; i.e., if the patch is in the game and not part of the buffer area
         ask pasture currentOwner [
           if (position neighborOwner neighborList = false) [
             set neighborList lput neighborOwner neighborList
           ]
         ]
       ]
      ] 
    ]

  ]
  
end


to listen
  
  ;; this is the main message processing procedure for the game.  this procedure responds to hubnet messages, one at a time, as long as the 'Listen Clients' button is down
  ;; where appropriate, procedures have been exported
  
  ;; while there are messages to be processed
  while [hubnet-message-waiting?] [
    
    ;; we use a 'message addressed' flag to avoid having to nest foreach loops (there is no switch/case structure in netlogo)
    set messageAddressed 0
    
    ;; get the next message in the queue
    hubnet-fetch-message  
      
    ;; if the message is that someone has entered the game
    if (hubnet-enter-message? and messageAddressed = 0)[
      
      ;;if the player has already been in the game, link them back in.  if the player is new, set them up to join
      ifelse (member? hubnet-message-source playerNames) [ 
        ;; pre-existing player whose connection cut out
        let newMessage word hubnet-message-source " is back."
        hubnet-broadcast-message newMessage
        
        ;; give the player the current game information
        let currentMessagePosition (position hubnet-message-source playerNames);  
        let currentPlayer currentMessagePosition + 1
        send-game-info currentMessagePosition
        
      ] ;; end previous player re-entering code
      
      [ ;; otherwise it's a new player trying to join
        
        ;; new players can only get registered if a game isn't underway
        if (gameInProgress = 0) [  ;;only let people join if we are between games
          
          ;; names are of the form name_ID - separate out the ID and store the names, IDs separately
          let tempName hubnet-message-source
          let hasHHID position "_" tempName
          let tempID []
          ifelse hasHHID != false [
            set tempID substring tempName (hasHHID + 1) (length tempName)
            set tempName substring tempName 0 hasHHID
          ] [
          set tempID 0
          ]
          set playerShortNames lput tempName playerShortNames
          set playerNames lput hubnet-message-source playerNames
          set playerHHID lput tempID playerHHID
          
          ;; add the new player, and give them a color
          set numPlayers numPlayers + 1
          set playerPosition lput numPlayers playerPosition
          set playerHerdColor lput (item (numPlayers - 1) colorList) playerHerdColor
          
          ;; let everyone know
          let newMessage word hubnet-message-source " has joined the game."
          hubnet-broadcast-message newMessage
        ]  ;; end new player code
      ]
      
      ;; mark this message as done
      set messageAddressed 1  
    ]
  
    ;; if the message is that someone left
    if (hubnet-exit-message? and messageAddressed = 0)[
      
      ;; nothing to do but let people know
      let newMessage word hubnet-message-source " has left.  Waiting."
      hubnet-broadcast-message newMessage
      
      ;; mark the message done
      set messageAddressed 1
    ]
      
    ;;the remaining cases are messages that something has been tapped, which are only processed if 1) a game is underway, 2) the message hasn't been addressed earlier, and 3) the player is in the game  
    if (gameInProgress = 1 and messageAddressed = 0 and (member? hubnet-message-source playerNames))[
  
      ;; identify the sender
      let currentMessagePosition (position hubnet-message-source playerNames);  ;;who the message is coming from, indexed from 0
      let currentPlayer (currentMessagePosition + 1); ;;who the player is, indexed from 1
      
      if hubnet-message-tag = "View" [  ;; the current player tapped something
        
        ;;identify the patch
        
        let xPatch (item 0 hubnet-message)
        let yPatch (item 1 hubnet-message)
        let xPixel (xPatch - min-pxcor + 0.5) * patch-size
        let yPixel (max-pycor + 0.5 - yPatch) * patch-size
        
        ;; if it's a pasture turn and the player taps a pasture, process it as a herd update (patches whose x is > 0 are pasture)
        if (xPatch > 0 and messageAddressed = 0 and (item (currentPhase  - 1) phasePasture = 1)) [ 
               
          ;; use the update-herd procedure
          update-herd (currentPlayer)
          
          ;; message is done
          set messageAddressed 1
        ]
        
        ;; if the tap is on the 'confirm button'
        if clicked-button (confirmPixLoc) [
          
          ;; if the player hasn't already clicked confirm this phase
          if item (currentPlayer - 1) playerConfirm = 0 [
            
            ;; mark the confirm and record
            let newMessage word (item (currentPlayer - 1) playerNames) " clicked confirm."
            hubnet-broadcast-message newMessage 
            file-print (word (item (currentPlayer - 1) playerNames) " clicked confirm at " date-and-time)
            
            set playerConfirm replace-item (currentPlayer - 1) playerConfirm 1
            
            ;; if players are confirming the end of phase (and not the receipt of between-year information
            if(showingGameInformation = 0) [ ;; mark the board as 'confirmed
              
              ;; darken the pasture to mark the confirm to the player
              ask patches with [pxcor >= 0] [hubnet-send-override (item (currentPlayer - 1) playerNames) self "pcolor" [(map [? / 5] pcolor)]];
            ]
            
            ;; update the player's information
            send-game-info (currentPlayer - 1)
            
            ;; if EVERYONE has now confirmed, move to advance-phase
            if (sum playerConfirm = numPlayers) [
              advance-phase 
            ]
          ]
          
          ;; mark message done
          set messageAddressed 1
        ]
        
        ;; if the player clicked to add additional insurance contracts
        if (clicked-button (insuredPlusPixLoc) and item (currentPhase - 1) phaseInsure = 1) [   
          
          ;; if the player can afford it
          if (item (currentPlayer - 1) playerScores >= insureCost) [
            
            
            ;; add an insurance contract to the current temp variables
            file-print (word (item (currentPlayer - 1) playerNames) " clicked plus insure at " date-and-time)  
            set playerTempInsuredAnimals replace-item (currentPlayer - 1) playerTempInsuredAnimals ((item (currentPlayer - 1) playerTempInsuredAnimals) + 1)
            set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - insureCost)
            
            ;; update info
            send-game-info (currentPlayer - 1)
          ]
          
          ;; message addressed
          set messageAddressed 1
        ]
        
        ;; if the player clicked to reduce the number of new insurance contracts
        if (clicked-button (insuredMinusPixLoc) and item (currentPhase - 1) phaseInsure = 1) [                   
          
          ;; if there are current, unconfirmed insurance contracts
          if (item (currentPlayer - 1) playerTempInsuredAnimals > 0 ) [
            
            ;; remove an insurance contract from the current temp variables
            file-print (word (item (currentPlayer - 1) playerNames) " clicked minus insure at " date-and-time)
            set playerTempInsuredAnimals replace-item (currentPlayer - 1) playerTempInsuredAnimals max(list ((item (currentPlayer - 1) playerTempInsuredAnimals) - 1) 0)
            set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + insureCost)
            
            ;; update info
            send-game-info (currentPlayer - 1)
          ]
          
          ;; message addressed
          set messageAddressed 1
        ]
        
        ;; if the player clicked to add fodder purchase 
        if (clicked-button (fodderPlusPixLoc) and item (currentPhase - 1) phaseFodder = 1)  [          
          
          ;; if there are animals in poor condition and the player can afford it
          ifelse (item 0 (item (currentPlayer - 1) playerTempHerds) > 0 and item (currentPlayer - 1) playerScores >= fodderCostOneStep) [
            ;; bump a poor to ok
            file-print (word (item (currentPlayer - 1) playerNames) " clicked plus fodder at " date-and-time)  
            set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 0 (item (currentPlayer - 1) playerTempHerds) ((item 0 (item (currentPlayer - 1) playerTempHerds)) - 1)
            set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) ((item 1 (item (currentPlayer - 1) playerTempHerds)) + 1)
            set playerTempFodder replace-item (currentPlayer - 1) playerTempFodder replace-item 1 (item (currentPlayer - 1) playerTempFodder) ((item 1 (item (currentPlayer - 1) playerTempFodder)) + 1)
            set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - fodderCostOneStep)
          ] [
          
          ;; otherwise, if there are animals in ok condition and the player can afford it          
          if (item 1 (item (currentPlayer - 1) playerTempHerds) > 0 and item (currentPlayer - 1) playerScores >= fodderCostOneStep) [
            ;; bump an ok to good 
            file-print (word (item (currentPlayer - 1) playerNames) " clicked plus fodder at " date-and-time)  
            set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) ((item 1 (item (currentPlayer - 1) playerTempHerds)) - 1)
            set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 2 (item (currentPlayer - 1) playerTempHerds) ((item 2 (item (currentPlayer - 1) playerTempHerds)) + 1)
            set playerTempFodder replace-item (currentPlayer - 1) playerTempFodder replace-item 2 (item (currentPlayer - 1) playerTempFodder) ((item 2 (item (currentPlayer - 1) playerTempFodder)) + 1)
            set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - fodderCostOneStep)
          ]
          ]
          
          ;; send info to player
          send-game-info (currentPlayer - 1)
          
          ;; message done
          set messageAddressed 1
        ]
        
        ;; if the player clicked to reduce the number of fodder purchases
        if (clicked-button (fodderMinusPixLoc) and item (currentPhase - 1) phaseFodder = 1) [         
          
          ;; if there are fodder purchases to reduce
          if (sum (item (currentPlayer - 1) playerTempFodder) > 0) [
            
            ;; if it's the case that a fodder purchase bumped an ok to a good this turn
            ifelse (item 2 (item (currentPlayer - 1) playerTempHerds) > 0 and item 2 (item (currentPlayer - 1) playerTempFodder) > 0) [
              ;; bump a good to ok
              file-print (word (item (currentPlayer - 1) playerNames) " clicked minus fodder at " date-and-time)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 2 (item (currentPlayer - 1) playerTempHerds) ((item 2 (item (currentPlayer - 1) playerTempHerds)) - 1)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) ((item 1 (item (currentPlayer - 1) playerTempHerds)) + 1)
              set playerTempFodder replace-item (currentPlayer - 1) playerTempFodder replace-item 2 (item (currentPlayer - 1) playerTempFodder) ((item 2 (item (currentPlayer - 1) playerTempFodder)) - 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + fodderCostOneStep)
            ] [
            
            ;; otherwise if it's the case that a fodder purchase bumped a poor to an ok
            if (item 1 (item (currentPlayer - 1) playerTempHerds) > 0 and item 1 (item (currentPlayer - 1) playerTempFodder) > 0) [
              ;; bump an ok to poor 
              file-print (word (item (currentPlayer - 1) playerNames) " clicked minus fodder at " date-and-time)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) ((item 1 (item (currentPlayer - 1) playerTempHerds)) - 1)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 0 (item (currentPlayer - 1) playerTempHerds) ((item 0 (item (currentPlayer - 1) playerTempHerds)) + 1)
              set playerTempFodder replace-item (currentPlayer - 1) playerTempFodder replace-item 1 (item (currentPlayer - 1) playerTempFodder) ((item 1 (item (currentPlayer - 1) playerTempFodder)) - 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + fodderCostOneStep)
            ]
            ]
            
          ]
          
          ;; update info
          send-game-info (currentPlayer - 1)
          
          ;; message addressed
          set messageAddressed 1
        ]
        
        
        ;; if the player clicked to add to the number of new animal purchases
        if (clicked-button (buyAnimalsPlusPixLoc) and item (currentPhase - 1) phaseAnimal = 1)  [  
          file-print (word (item (currentPlayer - 1) playerNames) " clicked plus buy animals at " date-and-time)  
          
          ;; if the player can afford it
          if (item (currentPlayer - 1) playerTempScores >= buyCalfCost) [
           ;; buy a new calf
           set playerTempCalves replace-item (currentPlayer - 1) playerTempCalves replace-item 0 (item (currentPlayer - 1) playerTempCalves) (item 0 (item (currentPlayer - 1) playerTempCalves) + 1)
           set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - buyCalfCost)
          ]    
          
          ;; update info and mark message addressed
          send-game-info (currentPlayer - 1)
          set messageAddressed 1
        ]
        
        ;; if the player clicked to reduce the number of new animal purchases
        if (clicked-button (buyAnimalsMinusPixLoc) and item (currentPhase - 1) phaseAnimal = 1) [      
          file-print (word (item (currentPlayer - 1) playerNames) " clicked minus buy animals at " date-and-time)
          
          ;; if there are animal purchases to reduce
          if (sum (item (currentPlayer - 1) playerTempCalves) > 0) [ ;;i.e., there are still new calves in the basket
            ;; put back a new calf
            file-print (word (item (currentPlayer - 1) playerNames) " clicked minus buy animals at " date-and-time)
            
            
            ;; we ALLOW calves that were purchased in previous phases (but are still calves) to be returned.  thus, we look for calves purchased in other phases to return
            let calfIndex 0
            let calfNotFound true
            while [calfNotFound] [
              ifelse (item calfIndex item (currentPlayer - 1) playerTempCalves > 0) [ set calfNotFound false] [set calfIndex (calfIndex + 1)]
            ]
            set playerTempCalves replace-item (currentPlayer - 1) playerTempCalves replace-item calfIndex (item (currentPlayer - 1) playerTempCalves) (item calfIndex (item (currentPlayer - 1) playerTempCalves) - 1)
            set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + buyCalfCost)
          ]   
          
          ;; update info and mark message addressed
          send-game-info (currentPlayer - 1)
          set messageAddressed 1
        ]
        
        ;; if the player clicked to sell animals (adult animals only)
        if (clicked-button (sellAnimalsPlusPixLoc) and item (currentPhase - 1) phaseAnimal = 1) [  
          
          ;; if there are adult animals to sell
          if (sum (item (currentPlayer - 1) playerTempHerds) > 0) [
            file-print (word (item (currentPlayer - 1) playerNames) " clicked plus sell animals at " date-and-time) 
            
            ;; start with the possibility of selling a good one
            ifelse (item 2 (item (currentPlayer - 1) playerTempHerds) > 0) [
              ;; sell a good one
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 2 (item (currentPlayer - 1) playerTempHerds) ((item 2 (item (currentPlayer - 1) playerTempHerds)) - 1)
              set playerTempSoldAnimals replace-item (currentPlayer - 1) playerTempSoldAnimals replace-item 2 (item (currentPlayer - 1) playerTempSoldAnimals) ((item 2 (item (currentPlayer - 1) playerTempSoldAnimals)) + 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + saleValueGood)

            ] [
            
            ;; otherwise try to sell an ok one
            ifelse (item 1 (item (currentPlayer - 1) playerTempHerds) > 0) [
              ;; sell an ok one 
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) ((item 1 (item (currentPlayer - 1) playerTempHerds)) - 1)
              set playerTempSoldAnimals replace-item (currentPlayer - 1) playerTempSoldAnimals replace-item 1 (item (currentPlayer - 1) playerTempSoldAnimals) ((item 1 (item (currentPlayer - 1) playerTempSoldAnimals)) + 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + saleValueOk)
            ] [
            
              ;; otherwise sell a poor one
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 0 (item (currentPlayer - 1) playerTempHerds) ((item 0 (item (currentPlayer - 1) playerTempHerds)) - 1)
              set playerTempSoldAnimals replace-item (currentPlayer - 1) playerTempSoldAnimals replace-item 0 (item (currentPlayer - 1) playerTempSoldAnimals) ((item 0 (item (currentPlayer - 1) playerTempSoldAnimals)) + 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + saleValuePoor)
            ]
            ]
            
          ]
          
          ;; update info and mark message addressed
          send-game-info (currentPlayer - 1)
          set messageAddressed 1
        ]        
        
        ;; if the player clicked to reduce the number of animals sold
        if (clicked-button (sellAnimalsMinusPixLoc) and item (currentPhase - 1) phaseAnimal = 1) [
          
          
          ;; if there are animals marked sold to be reduced
          if (sum (item (currentPlayer - 1) playerTempSoldAnimals) > 0) [
            
            ;; start by trying to take back a poor one
            ifelse (item 0 (item (currentPlayer - 1) playerTempSoldAnimals) > 0 and item (currentPlayer - 1) playerScores > saleValuePoor) [
              ;; take back a poor one
              file-print (word (item (currentPlayer - 1) playerNames) " clicked minus sell animals at " date-and-time)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 0 (item (currentPlayer - 1) playerTempHerds) ((item 0 (item (currentPlayer - 1) playerTempHerds)) + 1)
              set playerTempSoldAnimals replace-item (currentPlayer - 1) playerTempSoldAnimals replace-item 0 (item (currentPlayer - 1) playerTempSoldAnimals) ((item 0 (item (currentPlayer - 1) playerTempSoldAnimals)) - 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - saleValuePoor)

            ] [
            
            ;; otherwise take back an ok one
            ifelse (item 1 (item (currentPlayer - 1) playerTempSoldAnimals) > 0 and item (currentPlayer - 1) playerScores > saleValueOk) [
              ;; take back an ok one 
              file-print (word (item (currentPlayer - 1) playerNames) " clicked minus sell animals at " date-and-time)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) ((item 1 (item (currentPlayer - 1) playerTempHerds)) + 1)
              set playerTempSoldAnimals replace-item (currentPlayer - 1) playerTempSoldAnimals replace-item 1 (item (currentPlayer - 1) playerTempSoldAnimals) ((item 1 (item (currentPlayer - 1) playerTempSoldAnimals)) - 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - saleValueOk)
            ] [
            
            ;; otherwise take back a good one
            if (item 2 (item (currentPlayer - 1) playerTempSoldAnimals) > 0 and item (currentPlayer - 1) playerScores > saleValueGood) [
              ;; take back a good one
              file-print (word (item (currentPlayer - 1) playerNames) " clicked minus sell animals at " date-and-time)
              set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 2 (item (currentPlayer - 1) playerTempHerds) ((item 2 (item (currentPlayer - 1) playerTempHerds)) + 1)
              set playerTempSoldAnimals replace-item (currentPlayer - 1) playerTempSoldAnimals replace-item 2 (item (currentPlayer - 1) playerTempSoldAnimals) ((item 2 (item (currentPlayer - 1) playerTempSoldAnimals)) - 1)
              set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) - saleValueGood)
            ]
            ]
            ]
            
          ]          
          
          ;; update info and mark message addressed
          send-game-info (currentPlayer - 1)
          set messageAddressed 1
        ] 

        ;; if the message still hasn't been addressed, it means players clicked in a place that they weren't meant to - ignore it
        set messageAddressed 1
      ] ;; end ifelse view
     
      
    ] 
    

  ]
  
  
end

to show-game-information
  
  ;; provide a summary of the current game state, between years
  
  ;; make all pasture patches black
  foreach playerPosition [
    set playerConfirm replace-item (? - 1) playerConfirm 0
    ask patches with [pxcor >= 0] [hubnet-send-override (item (? - 1) playerNames) self "pcolor" [0]];
  ]
  
  ;; set the scaling variables for the display
  let yConvertPatch (numPatches / 50)  ;;scaling vertical measures based on the currently optimized size of 50
  let xyConvertPatchPixel (patch-size / 14)  ;; scaling vertical and horizontal measures based on currently optimized patch size of 14
  
  ;; hide the animals and show the scorecards
  ask animals [set hidden? true]
  ask scorecards with [identity = "inGameInformation"] [ set hidden? false]
  
  ;; if it's the end of the game, we convert the herd to a point value; otherwise, we show the current animals
  ifelse (gameInProgress = 0) [ ;;end of game, final score
    ask scorecards with [label = "Animals"] [set label "Total Score"]
    
    ;;convert herds to total point value 
    foreach playerPosition [
      let herdValue 0
      set herdValue herdValue + ((item 0 item (? - 1) playerHerds) + sum (item (? - 1) playerCalves)) * saleValuePoor
      set herdValue herdValue + ((item 1 item (? - 1) playerHerds)) * saleValueOk
      set herdValue herdValue + ((item 2 item (? - 1) playerHerds)) * saleValueGood
      ask scorecards with [identity = (word item (? - 1) playerNames "CurrentScore")]  [set hidden? false set label item (? - 1) playerScores]
      ask scorecards with [identity = (word item (? - 1) playerNames "FinalScore")]  [set label-color yellow set hidden? false set label ((item (? - 1) playerScores) + herdValue)]
    ]
  ] [
  
  ;; for each player, randomly place agents for each animal, colored appropriately, as an indicator of their herd to all players
  foreach playerPosition [
    ask scorecards with [identity = (word item (? - 1) playerNames "CurrentScore")]  [set hidden? false set label item (? - 1) playerTempScores]
    let animalsToPlace sum (item (? - 1) playerHerds) + sum (item (? - 1) playerCalves)
    while [animalsToPlace > 0] [
      ask one-of patches with [pycor < max-pycor - (5 + (? - .5) * patchesPerInfoLine) * yConvertPatch and pycor > max-pycor - (5 + (? + 0.5) * patchesPerInfoLine) * yConvertPatch and pxcor > 29 * yConvertPatch and pxcor < 42 * yConvertPatch] [
        sprout-animals 1 [
          set xcor pxcor - 0.5 + random-float 1
          set ycor pycor - 0.5 + random-float 1
          set owner ?
          set usingPasture -99
          set color item (? - 1) playerHerdColor
          set size 0.75
        ]
      ]
      set animalsToPlace (animalsToPlace - 1) 
    ]
    ask n-of (item 0 item (? - 1) playerHerds + sum (item (? - 1) playerCalves)) animals with [owner = ?] [ set color color - 2]
    ask n-of (item 2 item (? - 1) playerHerds) animals with [owner = ? and color = item (? - 1) playerHerdColor] [ set color color + 2]
  ]
  ]
  
end



to clear-game-information
  
  ;; clear away the information displayed between years as game summary
  ask scorecards with [identity = "inGameInformation"] [ set hidden? true]
  foreach playerPosition [
    ask scorecards with [identity = (word item (? - 1) playerNames "CurrentScore")]  [set hidden? true]
    set playerConfirm replace-item (? - 1) playerConfirm 0
    ask patches with [pxcor >= 0] [hubnet-clear-override (item (? - 1) playerNames) self "pcolor"]
    ask animals with [usingPasture = -99] [die]
    ask animals with [usingPasture > 0] [set hidden? false]
  ]
  
end

to advance-phase
  
  ;; called once at the end of every phase, once all players have clicked 'confirm'.  depending on the phases listed for the current turn, different things happen
  
  ;; it is called twice between the end of the last phase of a year and the first phase of another.  the first time, it will launch the 'show-game-information' routine and exit; 
  ;; once players have clicked confirm to exit the game information, it will be called again to finish advancing the phase

  ; if game information is not currently showing (i.e., this is the first time executed after end of phase)
  ifelse (showingGameInformation = 0) [ ;; do everything here that should happen before information is shared
    
    
    ;;if insurance was offered this turn, reset the insurance clock; otherwise advance it
    ifelse item (currentPhase - 1) phaseInsure = 1 [
      set insurancePhaseRemaining insurePeriod
    ] [
    if item (currentPhase - 1) phasePasture = 1 [
      set insurancePhaseRemaining max (list 0 (insurancePhaseRemaining - 1))
    ]
    ]
    
    ;; if there are insurance contracts to test for payouts, do so
    if (insurancePhaseRemaining = 0 and sum playerTempInsuredAnimals > 0) [ ;; contracts to examine
      file-print "Insurance contracts Evaluated"
      let averageGrass mean sublist pastGrassList (length pastGrassList - insurePeriod) (length pastGrassList)
      if averageGrass < insureTrigger [
        file-print "Insurance contracts are triggered"
        foreach playerPosition [
          let currentPlayer ?
          let currentInsured item (currentPlayer - 1) playerInsuredAnimals
          if currentInsured > 0 [
            set playerTempScores replace-item (currentPlayer - 1) playerTempScores ((item (currentPlayer - 1) playerTempScores) + currentInsured * insurePayout )
          ]
        ]
      ]
      foreach playerPosition [
        let currentPlayer ?
        set playerTempInsuredAnimals replace-item (currentPlayer - 1) playerTempInsuredAnimals 0 
      ] 
    ]
    
    ;;update herd size based on whatever decisions were made before the last 'confirm'   
    foreach playerPosition [
      let currentPlayer ?

      ;;let any calves advance in phase
      set playerTempHerds replace-item (currentPlayer - 1) playerTempHerds replace-item 1 (item (currentPlayer - 1) playerTempHerds) (item 1 (item (currentPlayer - 1) playerTempHerds) + last (item (currentPlayer - 1) playerTempCalves))
      foreach (n-values (phasesCalf - 1) [phasesCalf - 1 - ?]) [
        set playerTempCalves replace-item (currentPlayer - 1) playerTempCalves replace-item ? (item (currentPlayer - 1) playerTempCalves) (item (? - 1) (item (currentPlayer - 1) playerTempCalves))
      ]
      set playerTempCalves replace-item (currentPlayer - 1) playerTempCalves replace-item 0 (item (currentPlayer - 1) playerTempCalves) 0


      ;; replace animal agents with the appropriate current herd
      let currentPasture -88
      if (item (currentPlayer - 1) playerHerdOnBoard = 1) [
        set currentPasture [usingPasture] of one-of animals with [owner = currentPlayer]
      ]
      let animalsToPlace sum (item (currentPlayer - 1) playerTempHerds) + sum (item (currentPlayer - 1) playerTempCalves)
      ask animals with [owner = currentPlayer] [die]
      place-animals animalsToPlace currentPlayer currentPasture
    ]
    
    ;;If the previous turn was a pasturing turn (i.e., actual time passed), then run grass model.    
    if item (currentPhase - 1) phasePasture = 1 [
      let currentRain item 0 grassPhaseList
      set pastGrassList lput (first grassPhaseList) pastGrassList
      set grassPhaseList but-first grassPhaseList
      
      ask animals [set cumulativeNeed 0 set cumulativeGrass 0]
      
      foreach (n-values phaseLengthDays [?]) [
        ask pastures [
          
          ;; first have new grass grow
          let currentPasture who
          let currentGrass [pastureGrowth] of one-of patches with [pastureNumber = currentPasture] 
          let newGrowth grassR * currentGrass * (1 - (currentGrass / grassK) ) * (1 - (currentRain / grassE0))
          set currentGrass currentGrass + newGrowth
          
          ;; now have cattle consume grass
          let undergroundGrass (min (list (grassUndergroundFraction * grassK * sizePasture) (currentGrass * sizePasture)))
          let totalAvailableGrass currentGrass * sizePasture - undergroundGrass
          ask animals with [usingPasture = currentPasture] [
            let currentNeed 0
            ifelse age = "calf" [set cumulativeNeed cumulativeNeed + calfNeeds set currentNeed calfNeeds] [ set cumulativeNeed cumulativeNeed + animalNeeds set currentNeed animalNeeds]
            ifelse totalAvailableGrass > 0 [set cumulativeGrass cumulativeGrass + min (list totalAvailableGrass currentNeed)] [stop]
          ]
          
          ;; update all patches in the same pasture with the same level of grass
          set currentGrass (totalAvailableGrass + undergroundGrass) / sizePasture
          ask patches with [pastureNumber = currentPasture] [set pastureGrowth currentGrass]
        ]
      ]
      
      ;; update appearance of grass patches
      ask patches with [pxcor > 0] [ ;; update patch color
        let currentRGB_R (1 - (pastureGrowth / grassK)) * rgb_R
        let currentColor (list currentRGB_R rgb_G rgb_B)
        set pcolor currentColor 
      ]
            
      ;;(still within pasture turn) update state of animals and see if they survive
      ask animals [
        
        ;; update state of the animal
        ifelse (cumulativeGrass / (max (list cumulativeNeed 1)) < downThreshold) [ 
          set state (max (list 0 (state - 1)))
        ] [
        if (cumulativeGrass / (max (list cumulativeNeed 1)) >= upThreshold) [
          set state (min (list 2 (state + 1)))
        ]
        ]
        
        ;; update appearance based on state
        ifelse state = 0 [set color (item (owner - 1) playerHerdColor) - 2] [ifelse state = 1 [set color (item (owner - 1) playerHerdColor)] [set color (item (owner - 1) playerHerdColor) + 2]]
        
        ;; set the likelihood of death based on their state or age
        let probDeath 1
        ifelse state = 0 [set probDeath probDeathPoor] [ifelse state = 1 [set probDeath probDeathOk] [set probDeath probDeathGood]]
        if age = "calf" [set probDeath probDeathOk] ;; for calves, 'state' is irrelevant...
        
        ;; if the animal dies, and it is a calf, randomly select the 'phase' of calf to remove.  full grown animals are more easily just counted afterward
        if random-float 1 < probDeath [
          ;;update the player calf counts as appropriate.  the rest of the herd is easy enough to just count afterward, but here we are randomly removing a calf in a random phase
          ifelse age = "calf" [
            file-print (word (item (owner - 1) playerNames) " lost one calf")
            let culledCalf false
            while [culledCalf = false] [
              let guessPhase random numPhases
              if item guessPhase item (owner - 1) playerTempCalves > 0 [
                set playerTempCalves replace-item (owner - 1) playerTempCalves replace-item guessPhase (item (owner - 1) playerTempCalves) ((item guessPhase (item (owner - 1) playerTempCalves)) - 1) 
              ]
            ]
          ] [
          file-print (word (item (owner - 1) playerNames) " lost one adult animal")
          ] 
          
          die
        ]
      ]
      
      ;; we dealt with updating the calf counts in the 'ask animals' loop, but now we have to update the adult animal counts, in case some of them died
      foreach playerPosition [
       let tempHerdList (list (count animals with [owner = ? and age != "calf" and state = 0]) (count animals with [owner = ? and age != "calf" and state = 1]) (count animals with [owner = ? and age != "calf" and state = 2]) )
       set playerTempHerds replace-item (? - 1) playerTempHerds tempHerdList
      ]
      
      
      ;; (still within pasturing) based on the animals that survived, allocate any 'keep' value to the owner
      foreach playerPosition [      
        ;;now that pasturing has finished, give the 'keep value' for the animals remaining
        if (item (currentPhase - 1) phasePasture = 1) [ ;; add 'keep values' for each animal
          let keepValue ((item 0 item (? - 1) playerTempHerds) + sum (item (? - 1) playerTempCalves)) * keepValuePoor
          set keepValue keepValue + (item 1 item (? - 1) playerTempHerds) * keepValueOk
          set keepValue keepValue + (item 2 item (? - 1) playerTempHerds) * keepValueGood
          set playerTempScores replace-item (? - 1) playerTempScores (item (? - 1) playerTempScores + keepValue)
          
        ]
      ] 
    ]   
    
    
    ;; update the permanent player variables with their current values from the within-turn 'temp' variables
    foreach playerPosition [      
      ;;update the main variables with the last turn's temp variables
      set playerHerds replace-item (? - 1) playerHerds (item (? - 1) playerTempHerds)
      set playerScores replace-item (? - 1) playerScores (item (? - 1) playerTempScores)
      set playerCalves replace-item (? - 1) playerCalves (item (? - 1) playerTempCalves)
      set playerInsuredAnimals replace-item (? - 1) playerInsuredAnimals (item (? - 1) playerTempInsuredAnimals)       
    ]
    
    
    ;; now that we've done all the things we might want to do before advancing the phase, move on and update the phase
    ;; if we are in the last phase of the year, we either need to advance to the next year or end game
    ifelse currentPhase = numPhases [
      ifelse currentYear = numYears [
        
        ask currentMarkers [set color gray]

        ;; game is over
        end-game
        stop
      ] [
      
      ;; year is advanced by one.  go to the 'game-information' routine, but leave a marker that we're doing that.  
      ;; after that has been shown, we'll come back here, but we don't want to advance the counters again.  we unfortunately can't 
      ;; just stay in this loop because we need to listen for 'confirms' again, and while we're in here, hubnet isn't listening
      set currentPhase 1
      set currentYear (currentYear + 1)
      
      ask currentMarkers [set color gray]
      ask currentMarkers with [identity = (word "phase" currentPhase)] [set color yellow]
    
      set showingGameInformation 1
      show-game-information
      stop    
      ]
    ] [
    
    ;; we are in the middle of a year.  advance the phase
    set currentPhase (currentPhase + 1)
    
    ask currentMarkers [set color gray]
    ask currentMarkers with [identity = (word "phase" currentPhase)] [set color yellow]
    ] ;; end of ifelse currentPhase = numPhases
  ] [
  
  ;; this executes if we are re-entering advance-phase after showing between-year in-game information
  clear-game-information
  set showingGameInformation 0
  ] ;; end of ifelse (showingGameInformation = 0)
         
  ;; update game file       
  file-print (word "Advance to Year " currentYear ", Phase " currentPhase " at " date-and-time)
  file-print (word "Player Names: " playerNames)
  file-print (word "Player Calves: " playerCalves)  
  file-print (word "Player Herds: " playerHerds)
  file-print (word "Player Insurance: " playerInsuredAnimals)
  file-print (word "Player Scores: " playerScores)
  file-print (word "Player Herd on Board?: " playerHerdOnBoard)
  
  ;; if pasturing is not a part of the phase we just entered, darken the pasture so it's clear.  otherwise, make it bright again
  ifelse (item (currentPhase - 1) phasePasture) = 0 [
    ask animals [set hidden? true]
    foreach (n-values numPlayers [?]) [
      ask patches with [pxcor >= 0] [hubnet-send-override (item (?) playerNames) self "pcolor" [(map [? / 5] pcolor)]];
    ]
  ] [
    ask animals with [usingPasture > 0] [set hidden? false]
    foreach (n-values numPlayers [?]) [  
      ask patches with [pxcor >= 0] [hubnet-clear-override (item (?) playerNames) self "pcolor" ];
    ]
  ]
  
  
  ;; update what buttons are visible based on what actions are included in the current phase
  ifelse (item (currentPhase - 1) phaseInsure) = 0 [ask blocks with [identity = "insureBlock"] [set hidden? false]] [ask blocks with [identity = "insureBlock"] [set hidden? true]]
  ifelse (item (currentPhase - 1) phaseFodder) = 0 [ask blocks with [identity = "fodderBlock"] [set hidden? false]] [ask blocks with [identity = "fodderBlock"] [set hidden? true]]
  ifelse (item (currentPhase - 1) phaseAnimal) = 0 [ask blocks with [identity = "buyBlock"] [set hidden? false]] [ask blocks with [identity = "buyBlock"] [set hidden? true]]
  ifelse (item (currentPhase - 1) phaseAnimal) = 0 [ask blocks with [identity = "sellBlock"] [set hidden? false]] [ask blocks with [identity = "sellBlock"] [set hidden? true]]
    
   
  ;; reset our within-round 'temp' variables as appropriate, and update all player's information
  set playerTempHerds playerHerds
  set playerTempScores playerScores
  set playerTempCalves playerCalves
  set playerTempInsuredAnimals playerInsuredAnimals
  foreach playerPosition [
    set playerConfirm replace-item (? - 1) playerConfirm 0
    set playerTempFodder replace-item (? - 1) playerTempFodder (list 0 0 0)
    set playerTempSoldAnimals replace-item (? - 1) playerTempSoldAnimals (list 0 0 0)
    
    send-game-info (? - 1)
  ]
end

to end-game
  
  ;; at the end of the game, show final information, mark the game as stopped, and finalize files
  
  set gameInProgress 0
  show-game-information
  
  file-close
  
  file-open "completedGames.csv" 
  file-print gameName
  file-close  
  

  
end

to send-game-info [currentPosition]
  
  ;; sends current, player-specific game info to the specified player.  this is done by asking 'scorecard' agents to override the label they are showing to the particular player
  
  ask scorecards with [identity = "poorHerd"]  [hubnet-send-override (item currentPosition playerNames) self "label" [item 0 (item currentPosition playerTempHerds)] ]
  ask scorecards with [identity = "okHerd"]  [hubnet-send-override (item currentPosition playerNames) self "label" [item 1 (item currentPosition playerTempHerds)] ]
  ask scorecards with [identity = "goodHerd"]  [hubnet-send-override (item currentPosition playerNames) self "label" [item 2 (item currentPosition playerTempHerds)] ]
  ask scorecards with [identity = "year"]  [hubnet-send-override (item currentPosition playerNames) self "label" [currentYear] ]       
  ask scorecards with [identity = "phase"]  [hubnet-send-override (item currentPosition playerNames) self "label" [currentPhase] ]     
  ask scorecards with [identity = "score"]  [hubnet-send-override (item currentPosition playerNames) self "label" [item currentPosition playerTempScores] ]   
  ask scorecards with [identity = "insuredAnimals"]  [hubnet-send-override (item currentPosition playerNames) self "label" [item currentPosition playerTempInsuredAnimals] ]   
  ask scorecards with [identity = "calves"]  [hubnet-send-override (item currentPosition playerNames) self "label" [sum (item currentPosition playerTempCalves)] ]   
  ask scorecards with [identity = "changeFodder"]  [ifelse (sum (item currentPosition playerTempFodder) > 0) [
      hubnet-send-override (item currentPosition playerNames) self "label" [(word "(" sum (item currentPosition playerTempFodder) ")")] 
      hubnet-send-override (item currentPosition playerNames) self "hidden?" [false]
      ][hubnet-send-override (item currentPosition playerNames) self "hidden?" [true]]
  ]
  ask scorecards with [identity = "changeCalves"]  [ifelse (sum (item currentPosition playerTempCalves) != sum (item currentPosition playerCalves)) [
      hubnet-send-override (item currentPosition playerNames) self "label" [(word "(" (sum (item currentPosition playerTempCalves) - sum (item currentPosition playerCalves)) ")")] 
      hubnet-send-override (item currentPosition playerNames) self "hidden?" [false]
      ][hubnet-send-override (item currentPosition playerNames) self "hidden?" [true]]
  ]
  ask scorecards with [identity = "changeAnimals"]  [ifelse (sum (item currentPosition playerTempHerds) != sum (item currentPosition playerHerds)) [
      hubnet-send-override (item currentPosition playerNames) self "label" [(word "(" (sum (item currentPosition playerTempHerds) - sum (item currentPosition playerHerds)) ")")] 
      hubnet-send-override (item currentPosition playerNames) self "hidden?" [false]
      ][hubnet-send-override (item currentPosition playerNames) self "hidden?" [true]]
  ]
end

to-report clicked-button [ currentPixLoc ]
  
  ;; checks the boundaries of a click message against those of a 'button' to see if it was the one clicked
  
  let xPixel ((item 0 hubnet-message) - min-pxcor + 0.5) * patch-size
  let yPixel (max-pycor + 0.5 - (item 1 hubnet-message)) * patch-size
  let xPixMin item 0 currentPixLoc
  let xPixMax item 0 currentPixLoc + item 2 currentPixLoc
  let yPixMin item 1 currentPixLoc
  let yPixMax item 1 currentPixLoc + item 3 currentPixLoc
  ifelse xPixel > xPixMin and xPixel < xPixMax and yPixel > yPixMin and yPixel < yPixMax [  ;; player "clicked"  the current button 
    report true
  ] [
    report false
  ]
  
end

to place-animals [animalsToPlace currentPlayer currentPasture]
  
  ; this creates and places animals.  it is executed at every new turn, as it is just easier to make new animals when there has been a change in the herd
  
  ; if there are animals to place
  while [animalsToPlace > 0] [
    
    ; check if they are currently on the board or not - the code -88 is used for 'not currently pastured'
    ifelse (currentPasture > 0) [ ;;animals are on a pasture
      
      ; if they're in a pasture, place animals in that pasture
      ask one-of patches with [pastureNumber = currentPasture] [
        sprout-animals 1 [
          set xcor pxcor - 0.5 + random-float 1
          set ycor pycor - 0.5 + random-float 1
          set owner currentPlayer
          set usingPasture currentPasture
          set color item (currentPlayer - 1) playerHerdColor
          set size 0.75
          set state 1
        ]
      ]
    ] [ ;; animals are not on a pasture, so just put them at the origin and hide them
    ask patch 0 0 [
      sprout-animals 1 [
        set xcor pxcor - 0.5 + random-float 1
        set ycor pycor - 0.5 + random-float 1
        set owner currentPlayer
        set usingPasture currentPasture
        set color item (currentPlayer - 1) playerHerdColor
        set size 0.75
        set state 1
        set hidden? true
      ]
    ]
    
    ]
    set animalsToPlace (animalsToPlace - 1) 
  ]
  
  ;; update the state and age of the herd as appropriate.  note that 'state' for calves is unused and not relevant
  ask n-of (item 0 item (currentPlayer - 1) playerHerds) animals with [owner = currentPlayer] [ set color color - 2 set state 0]
  ask n-of (sum (item (currentPlayer - 1) playerCalves)) animals with [owner = currentPlayer and color = item (currentPlayer - 1) playerHerdColor] [ set age "calf" set color color - 2 set state 0]
  ask n-of (item 2 item (currentPlayer - 1) playerHerds) animals with [owner = currentPlayer and color = item (currentPlayer - 1) playerHerdColor] [ set color color + 2 set state 1]
  
end

to update-herd [ currentPlayer ] 
  
  ;; executed whenever a player clicks on a pasture patch during a pasture turn
  
  ;; logic is as follows:  1) if player's herd is not currently pastured, place them in the pasture clicked. 
  ;; 2) if player's herd is already pastured, and in the pasture clicked, remove them
  ;; 3) if player's herd is already pastured, but in a different pasture, move them to this one 
  
  ; identify the patch clicked
  let xPatch (item 0 hubnet-message)
  let yPatch (item 1 hubnet-message)
  
  ; identify what pasture it belongs to
  let currentPasture [pastureNumber] of patch xPatch yPatch
  
  ; see if the player's herd is currently in a pasture
  ifelse (item (currentPlayer - 1) playerHerdOnBoard = 0) [
    ;; herd is not on the board - place them here
    
    ; are there any animals in the herd?
    let animalsToPlace sum (item (currentPlayer - 1) playerHerds) + sum (item (currentPlayer - 1) playerCalves)

    ; if so, mark the output file that the animals were pastured and where
    if animalsToPlace > 0 [
      set playerHerdOnBoard (replace-item (currentPlayer - 1) playerHerdOnBoard 1)
      let newMessage word (item (currentPlayer - 1) playerNames) " placed animals."
      hubnet-broadcast-message newMessage 
      file-print (word (item (currentPlayer - 1) playerNames) " placed animals in pasture " currentPasture " at " date-and-time)   

      ; move the animals to this pasture and show them
      ask animals with [owner = currentPlayer] [
        let newPatch one-of patches with [pastureNumber = currentPasture]               
        setxy ([pxcor] of newPatch - 0.5 + random-float 1) ([pycor] of newPatch - 0.5 + random-float 1)
        set usingPasture currentPasture
        set hidden? false
      ]

    ]


  ] [
  
  ;; herd is on the board - take them off or move them
  
  ; find out where the herd is
  let herdPasture [usingPasture] of one-of animals with [owner = currentPlayer]
  ifelse (herdPasture = currentPasture) [
    ;; herd is already in this pasture - 'remove' them from board (hide them)
    ask animals with [owner = currentPlayer] [
      set hidden? true
      set usingPasture -88 
    ]
    
    ; mark output file that they've been removed
    set playerHerdOnBoard (replace-item (currentPlayer - 1) playerHerdOnBoard 0)
    let newMessage word (item (currentPlayer - 1) playerNames) " removed animals."
    file-print (word (item (currentPlayer - 1) playerNames) " removed animals from pasture " currentPasture " at " date-and-time)
    hubnet-broadcast-message newMessage 
  ] [
  ;; herd is in another pasture - move them here
  ask animals with [owner = currentPlayer] [
    let newPatch one-of patches with [pastureNumber = currentPasture]               
    setxy ([pxcor] of newPatch - 0.5 + random-float 1) ([pycor] of newPatch - 0.5 + random-float 1)
    set usingPasture currentPasture
  ]
  
  ; mark output file that they've been moved
  let newMessage word (item (currentPlayer - 1) playerNames) " moved animals."
  file-print (word (item (currentPlayer - 1) playerNames) " moved animals to pasture " currentPasture " at " date-and-time)
  hubnet-broadcast-message newMessage             
  ] ;; end of herdPasture = currentPasture if/else
  
  ] ;; end of playerHerdOnBoard if/else
  
end
@#$#@#$#@
GRAPHICS-WINDOW
279
10
1569
841
-1
-1
40.0
1
50
1
1
1
0
0
0
1
-12
19
0
19
0
0
1
ticks
30.0

BUTTON
22
306
169
339
Launch Next Game
start-game
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
24
87
165
120
Launch Broadcast
start-hubnet
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
24
126
155
159
Listen to Clients
listen
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
26
669
164
714
language
language
"English"
0

BUTTON
27
721
185
754
Place Language Tiles
set-language
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
24
12
259
72
inputParameterFileName
experimentParameters.csv
1
0
String

INPUTBOX
23
173
126
233
sessionID
1
1
0
Number

BUTTON
22
254
165
287
Initialize Session
initialize-session
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

A multiplayer game for the use of a pasture commons, including options of fodder purchase and index insurance.

## HOW IT WORKS

This is a turn-based game, with each turn (phase) ending when all players have confirmed their actions for the phase.  Each phase can include any or all of the following:

> (P) Pasturing.  Players select a pasture to leave their herd in for the duration of the pasture phase.

> (I) Insurance.  Players may purchase index insurance contracts, whose payout is calibrated to the value of an animal, on the average evapotranspiration over some following number of periods, with some trigger value.

> (F) Fodder.  Players may purchase fodder supplements to raise the condition of current adult animals in their herd.

> (A) Animal markets.  Players may purchase new calves (who remain calves for some period of time) or sell current adult animals.

## GAME START INSTRUCTIONS

> 1. Log all of your tablets onto the same network.  If you are in the field using a portable router, this is likely to be the only available wifi network.

> 2. Open the game file on your host tablet.  Zoom out until it fits in your screen

> 3. If necessary, change the language setting on the host.

> 4. Click ‘Launch Broadcast’.  This will reset the software, as well as read in the file containing all game settings.  

> 5. Select ‘Mirror 2D view on clients’ on the Hubnet Control Center.  

> 6. Click ‘Listen Clients’ on the main screen.  This tells your tablet to listen for the actions of the client computers.  If there ever are any errors generated by Netlogo, this will turn off.  Make sure you turn it back on after clearing the error.

> 7. Open Hubnet on all of the client computers.  Enter the player names in the client computers, in the form ‘PlayerName_HHID’.   

> 8. If the game being broadcast shows up in the list, select it.  Otherwise, manually type in the server address (shown in ‘Hubnet Control Center’.  With the HooToo Tripmate routers, it should be of the form 10.10.10.X.

> 9. Click ‘Enter’ on each client.

> 10. Back on the host tablet, select the appropriate session ID, and click ‘Initialize Session’.

> 11. Click 'Launch Next Game' to start game.  

** A small bug – once you start *EACH* new game, you must have one client exit and re-enter.  For some reason the image files do not load initially, but will load on all client computers once a player has exited and re-entered.  I believe this is something to do with an imperfect match between the world size and the client window size, which auto-corrects on re-entry.  Be sure not to change the player name or number when they re-enter.


## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES


NonCropShare exploits the use of the bitmap extension, agent labeling, and hubnet overrides to get around the limitations of NetLogo's visualization capacities.

In the hubnet client, all actual buttons are avoided.  Instead, the world is extended, with patches to the right of the origin capturing elements of the game play, and patches to the left of the origin being used only to display game messages.

Language support is achieved by porting all in-game text to bitmap images that are loaded into the view.  The location of these images is optimized to a Dell Venue 8 Pro tablet, and will likely need some care if re-sized (it is necessary to think in both patch space and pixel space to place them correctly).  Scores are updated to the labels of invisible agents, whose values are overridden differently for each client.

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

bar
false
0
Rectangle -7500403 true true 0 0 300 30

blank
true
0

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
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

sheep 2
false
0
Polygon -7500403 true true 209 183 194 198 179 198 164 183 164 174 149 183 89 183 74 168 59 198 44 198 29 185 43 151 28 121 44 91 59 80 89 80 164 95 194 80 254 65 269 80 284 125 269 140 239 125 224 153 209 168
Rectangle -7500403 true true 180 195 195 225
Rectangle -7500403 true true 45 195 60 225
Rectangle -16777216 true false 180 225 195 240
Rectangle -16777216 true false 45 225 60 240
Polygon -7500403 true true 245 60 250 72 240 78 225 63 230 51
Polygon -7500403 true true 25 72 40 80 42 98 22 91
Line -16777216 false 270 137 251 122
Line -16777216 false 266 90 254 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square outline
false
4
Polygon -1184463 true true 15 15 285 15 285 285 15 285 15 30 30 30 30 270 270 270 270 30 15 30

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
VIEW
7
10
1287
810
0
0
0
1
1
1
1
1
0
1
1
1
-12
19
0
19

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
