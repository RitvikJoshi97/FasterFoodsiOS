import Foundation

enum WorkoutActivityDefinitionDefaults {
    private typealias Constants = WorkoutActivityDefinition.Constants

    static let defaultActivities: [WorkoutActivityDefinition] = [
        // Cardio & Running
        WorkoutActivityDefinition(
            id: Constants.cardio,
            name: "Cardio & Running",
            categories: [
                WorkoutCategoryDefinition(
                    id: "outdoor-run", name: "Outdoor Run",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "pace", name: "Pace", kind: .text(unit: "min/km")),
                        WorkoutParameterDefinition(
                            id: "elevation", name: "Elevation Gain", kind: .number(unit: "m")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "indoor-run", name: "Indoor Run (Treadmill)",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "incline", name: "Incline", kind: .number(unit: "%")),
                        WorkoutParameterDefinition(
                            id: "speed", name: "Speed", kind: .number(unit: "km/h")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "walking", name: "Walking",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "steps", name: "Steps", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "terrain", name: "Terrain",
                            kind: .options(["Flat", "Hilly", "Mixed"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "hiking", name: "Hiking",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "elevation", name: "Elevation Gain", kind: .number(unit: "m"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "difficulty", name: "Difficulty",
                            kind: .options(["Easy", "Moderate", "Hard", "Extreme"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "trail-run", name: "Trail Run",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "elevation", name: "Elevation Gain", kind: .number(unit: "m")),
                        WorkoutParameterDefinition(
                            id: "difficulty", name: "Technical Difficulty",
                            kind: .options(["Easy", "Moderate", "Hard"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "track-run", name: "Track Run",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "laps", name: "Laps", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "splits", name: "Split Times", kind: .text(unit: "")),
                    ]),
            ]
        ),

        // Cycling
        WorkoutActivityDefinition(
            id: Constants.cycling,
            name: "Cycling",
            categories: [
                WorkoutCategoryDefinition(
                    id: "outdoor-cycling", name: "Outdoor Cycling",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "avg-speed", name: "Average Speed", kind: .number(unit: "km/h")),
                        WorkoutParameterDefinition(
                            id: "elevation", name: "Elevation Gain", kind: .number(unit: "m")),
                        WorkoutParameterDefinition(
                            id: "terrain", name: "Terrain",
                            kind: .options(["Road", "Mountain", "Mixed"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "indoor-cycling", name: "Indoor Cycling (Spinning)",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km")),
                        WorkoutParameterDefinition(
                            id: "resistance", name: "Resistance Level", kind: .number(unit: "1-10")),
                        WorkoutParameterDefinition(
                            id: "rpm", name: "RPM", kind: .number(unit: "rpm")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "ebike", name: "E-Bike Rides",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "battery", name: "Battery Usage", kind: .number(unit: "%")),
                        WorkoutParameterDefinition(
                            id: "assist", name: "Assist Level",
                            kind: .options(["Eco", "Tour", "Sport", "Turbo"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "handcycle", name: "Handcycle",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "avg-speed", name: "Average Speed", kind: .number(unit: "km/h")),
                        WorkoutParameterDefinition(
                            id: "terrain", name: "Terrain",
                            kind: .options(["Flat", "Hilly", "Mixed"])),
                    ]),
            ]
        ),

        // Gym & Strength
        WorkoutActivityDefinition(
            id: Constants.gymStrength,
            name: "Gym & Strength",
            categories: [
                WorkoutCategoryDefinition(
                    id: "traditional-strength", name: "Traditional Strength Training",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "exercises", name: "Exercises", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "sets", name: "Sets", kind: .number(unit: "")),
                        WorkoutParameterDefinition(id: "reps", name: "Reps", kind: .text(unit: "")),
                        WorkoutParameterDefinition(
                            id: "weight", name: "Weight Lifted", kind: .number(unit: "kg")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "functional-strength", name: "Functional Strength Training",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "exercises", name: "Exercises", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "circuits", name: "Circuits", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "ratio", name: "Work:Rest Ratio", kind: .text(unit: "")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "core-training", name: "Core Training",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "exercises", name: "Exercises", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "hold", name: "Hold Time", kind: .number(unit: "seconds")),
                        WorkoutParameterDefinition(id: "reps", name: "Reps", kind: .text(unit: "")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "hiit", name: "High-Intensity Interval Training (HIIT)",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "work", name: "Work Intervals", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "rest", name: "Rest Intervals", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "ratio", name: "Work:Rest Ratio", kind: .text(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "max-hr", name: "Max Heart Rate", kind: .number(unit: "bpm")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "circuit-training", name: "Circuit Training",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "stations", name: "Stations", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "rounds", name: "Rounds", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "rest", name: "Rest Between Rounds", kind: .number(unit: "min")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "flexibility", name: "Flexibility / Mobility",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "stretches", name: "Stretches", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "hold", name: "Hold Time", kind: .number(unit: "seconds")),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus Area",
                            kind: .options([
                                "Full Body", "Upper Body", "Lower Body", "Back", "Hips",
                            ])),
                    ]),
            ]
        ),

        // Mind & Body
        WorkoutActivityDefinition(
            id: Constants.mindBody,
            name: "Mind & Body",
            categories: [
                WorkoutCategoryDefinition(
                    id: "yoga", name: "Yoga",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "style", name: "Style",
                            kind: .options([
                                "Hatha", "Vinyasa", "Ashtanga", "Bikram", "Yin", "Restorative",
                            ]), required: true),
                        WorkoutParameterDefinition(
                            id: "poses", name: "Poses", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus",
                            kind: .options(["Flexibility", "Strength", "Balance", "Meditation"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "pilates", name: "Pilates",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "exercises", name: "Exercises", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "equipment", name: "Equipment",
                            kind: .options(["Mat", "Reformer", "Cadillac", "Chair"])),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus",
                            kind: .options(["Core", "Full Body", "Flexibility"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "tai-chi", name: "Tai Chi",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "forms", name: "Forms", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "style", name: "Style",
                            kind: .options(["Yang", "Chen", "Wu", "Sun"])),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus",
                            kind: .options(["Balance", "Meditation", "Movement"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "mindful-cooldown", name: "Mindful Cooldown",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "breathing", name: "Breathing Exercises", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "meditation", name: "Meditation Time", kind: .number(unit: "min")),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus",
                            kind: .options(["Breathing", "Body Scan", "Mindfulness"])),
                    ]),
            ]
        ),

        // Water Sports
        WorkoutActivityDefinition(
            id: Constants.waterSports,
            name: "Water Sports",
            categories: [
                WorkoutCategoryDefinition(
                    id: "pool-swim", name: "Pool Swim",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "m"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "laps", name: "Laps", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "stroke", name: "Stroke",
                            kind: .options([
                                "Freestyle", "Backstroke", "Breaststroke", "Butterfly", "Mixed",
                            ])),
                        WorkoutParameterDefinition(
                            id: "pool-length", name: "Pool Length", kind: .number(unit: "m")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "open-water-swim", name: "Open Water Swim",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "temp", name: "Water Temperature", kind: .number(unit: "°C")),
                        WorkoutParameterDefinition(
                            id: "conditions", name: "Conditions",
                            kind: .options(["Calm", "Moderate", "Rough"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "surfing", name: "Surfing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "waves", name: "Waves Caught", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "height", name: "Wave Height", kind: .number(unit: "ft")),
                        WorkoutParameterDefinition(
                            id: "conditions", name: "Conditions",
                            kind: .options(["Clean", "Choppy", "Mushy"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "paddleboarding", name: "Stand-Up Paddleboarding",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "conditions", name: "Water Conditions",
                            kind: .options(["Flat", "Small Waves", "Choppy"])),
                        WorkoutParameterDefinition(
                            id: "board", name: "Board Type",
                            kind: .options(["All-Around", "Touring", "Racing"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "rowing", name: "Rowing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "m"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "split", name: "Split Time", kind: .text(unit: "min/500m")),
                        WorkoutParameterDefinition(
                            id: "stroke-rate", name: "Stroke Rate", kind: .number(unit: "spm")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type", kind: .options(["Indoor", "Outdoor"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "kayaking", name: "Kayaking",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "water-type", name: "Water Type",
                            kind: .options(["Lake", "River", "Ocean"])),
                        WorkoutParameterDefinition(
                            id: "difficulty", name: "Difficulty",
                            kind: .options(["Easy", "Moderate", "Advanced"])),
                    ]),
            ]
        ),

        // Winter Sports
        WorkoutActivityDefinition(
            id: Constants.winterSports,
            name: "Winter Sports",
            categories: [
                WorkoutCategoryDefinition(
                    id: "snowboarding", name: "Snowboarding",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "runs", name: "Runs", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "vertical", name: "Vertical Drop", kind: .number(unit: "m")),
                        WorkoutParameterDefinition(
                            id: "terrain", name: "Terrain",
                            kind: .options(["Groomed", "Powder", "Park", "Backcountry"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "skiing", name: "Skiing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "runs", name: "Runs", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "vertical", name: "Vertical Drop", kind: .number(unit: "m")),
                        WorkoutParameterDefinition(
                            id: "terrain", name: "Terrain",
                            kind: .options(["Groomed", "Powder", "Moguls", "Backcountry"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "cross-country-skiing", name: "Cross-Country Skiing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "distance", name: "Distance", kind: .number(unit: "km"),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "technique", name: "Technique",
                            kind: .options(["Classic", "Skate", "Mixed"])),
                        WorkoutParameterDefinition(
                            id: "terrain", name: "Terrain",
                            kind: .options(["Flat", "Rolling", "Hilly"])),
                    ]),
            ]
        ),

        // Combat / Mixed Training
        WorkoutActivityDefinition(
            id: Constants.combatMixed,
            name: "Combat / Mixed Training",
            categories: [
                WorkoutCategoryDefinition(
                    id: "boxing", name: "Boxing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "rounds", name: "Rounds", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "duration", name: "Round Duration", kind: .number(unit: "min")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options(["Sparring", "Heavy Bag", "Speed Bag", "Shadow Boxing"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "kickboxing", name: "Kickboxing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "rounds", name: "Rounds", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "duration", name: "Round Duration", kind: .number(unit: "min")),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus",
                            kind: .options(["Striking", "Kicking", "Combination"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "martial-arts", name: "Martial Arts",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "style", name: "Style",
                            kind: .options([
                                "Karate", "Taekwondo", "Judo", "Brazilian Jiu-Jitsu", "Muay Thai",
                            ]), required: true),
                        WorkoutParameterDefinition(
                            id: "belt", name: "Belt Level",
                            kind: .options([
                                "White", "Yellow", "Orange", "Green", "Blue", "Purple", "Brown",
                                "Black",
                            ])),
                        WorkoutParameterDefinition(
                            id: "focus", name: "Focus",
                            kind: .options(["Forms", "Sparring", "Self-Defense", "Fitness"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "dance-cardio", name: "Dance / Cardio Dance",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "style", name: "Style",
                            kind: .options(["Zumba", "Hip Hop", "Latin", "Jazz", "Contemporary"]),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "choreography", name: "Choreography",
                            kind: .options(["Beginner", "Intermediate", "Advanced"])),
                        WorkoutParameterDefinition(
                            id: "intensity", name: "Intensity",
                            kind: .options(["Low", "Moderate", "High"])),
                    ]),
            ]
        ),

        // Team & Field Sports
        WorkoutActivityDefinition(
            id: Constants.teamField,
            name: "Team & Field Sports",
            categories: [
                WorkoutCategoryDefinition(
                    id: "football", name: "Football",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "position", name: "Position",
                            kind: .options([
                                "Quarterback", "Running Back", "Wide Receiver", "Defense",
                                "Special Teams",
                            ])),
                        WorkoutParameterDefinition(
                            id: "plays", name: "Plays", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "yards", name: "Yards Gained", kind: .number(unit: "")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "basketball", name: "Basketball",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "points", name: "Points Scored", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "rebounds", name: "Rebounds", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "assists", name: "Assists", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options(["Pickup", "League", "Practice"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "volleyball", name: "Volleyball",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "sets", name: "Sets Played", kind: .number(unit: ""), required: true
                        ),
                        WorkoutParameterDefinition(
                            id: "position", name: "Position",
                            kind: .options(["Setter", "Hitter", "Libero", "Middle Blocker"])),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type", kind: .options(["Indoor", "Beach", "Grass"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "hockey", name: "Hockey",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "periods", name: "Periods", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "goals", name: "Goals", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "assists", name: "Assists", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type", kind: .options(["Ice", "Field", "Inline"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "cricket", name: "Cricket",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "overs", name: "Overs", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "runs", name: "Runs Scored", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "wickets", name: "Wickets Taken", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "format", name: "Format",
                            kind: .options(["Test", "ODI", "T20", "Practice"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "rugby", name: "Rugby",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "halves", name: "Halves", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "tries", name: "Tries", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "tackles", name: "Tackles", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type", kind: .options(["Union", "League", "Sevens"])),
                    ]),
            ]
        ),

        // Racket & Precision Sports
        WorkoutActivityDefinition(
            id: Constants.racketPrecision,
            name: "Racket & Precision Sports",
            categories: [
                WorkoutCategoryDefinition(
                    id: "tennis", name: "Tennis",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "sets", name: "Sets", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "games", name: "Games Won", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options(["Singles", "Doubles", "Practice"])),
                        WorkoutParameterDefinition(
                            id: "surface", name: "Surface",
                            kind: .options(["Hard Court", "Clay", "Grass", "Indoor"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "badminton", name: "Badminton",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "games", name: "Games", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "points", name: "Points Scored", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options(["Singles", "Doubles", "Mixed Doubles"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "table-tennis", name: "Table Tennis",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "games", name: "Games", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "points", name: "Points Scored", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type", kind: .options(["Singles", "Doubles"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "golf", name: "Golf",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "holes", name: "Holes Played", kind: .number(unit: ""),
                            required: true),
                        WorkoutParameterDefinition(
                            id: "score", name: "Score", kind: .number(unit: "")),
                        WorkoutParameterDefinition(id: "par", name: "Par", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options([
                                "Full Round", "9 Holes", "Driving Range", "Putting Practice",
                            ])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "pickleball", name: "Pickleball",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "games", name: "Games", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "points", name: "Points Scored", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type", kind: .options(["Singles", "Doubles"])),
                    ]),
            ]
        ),

        // Others
        WorkoutActivityDefinition(
            id: Constants.others,
            name: "Others",
            categories: [
                WorkoutCategoryDefinition(
                    id: Constants.healthKitImport, name: "Imported (Health App)",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "source", name: "Source", kind: .text(unit: "")),
                        WorkoutParameterDefinition(
                            id: "activity-type", name: "Activity Type", kind: .text(unit: "")),
                        WorkoutParameterDefinition(
                            id: "notes", name: "Notes", kind: .text(unit: "")),
                    ]),
                WorkoutCategoryDefinition(
                    id: "dance", name: "Dance",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "style", name: "Style",
                            kind: .options([
                                "Ballet", "Contemporary", "Hip Hop", "Latin", "Ballroom",
                            ]), required: true),
                        WorkoutParameterDefinition(
                            id: "level", name: "Level",
                            kind: .options(["Beginner", "Intermediate", "Advanced"])),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options(["Class", "Performance", "Social"])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "fitness-gaming", name: "Fitness Gaming",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "game", name: "Game", kind: .text(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "level", name: "Level", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "score", name: "Score", kind: .number(unit: "")),
                        WorkoutParameterDefinition(
                            id: "platform", name: "Platform",
                            kind: .options([
                                "Nintendo Switch", "PlayStation", "Xbox", "VR", "Mobile",
                            ])),
                    ]),
                WorkoutCategoryDefinition(
                    id: "climbing", name: "Climbing",
                    parameters: [
                        WorkoutParameterDefinition(
                            id: "routes", name: "Routes", kind: .number(unit: ""), required: true),
                        WorkoutParameterDefinition(
                            id: "difficulty", name: "Difficulty",
                            kind: .options(["5.0-5.5", "5.6-5.9", "5.10-5.12", "5.13+"])),
                        WorkoutParameterDefinition(
                            id: "type", name: "Type",
                            kind: .options(["Indoor", "Outdoor", "Bouldering"])),
                    ]),
            ]
        ),
    ]
}
