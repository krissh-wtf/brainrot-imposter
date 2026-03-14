--!strict

local Themes: { [string]: { string } } = {
	animals = { "cat", "dog", "elephant", "parrot", "dolphin", "penguin", "koala", "tiger" },
	food = { "pizza", "sushi", "croissant", "burger", "ramen", "tacos", "waffle", "pretzel" },
	sports = { "soccer", "tennis", "basketball", "swimming", "fencing", "rugby", "hockey", "archery" },
	countries = { "france", "japan", "brazil", "canada", "egypt", "iceland", "norway", "mexico" },
	instruments = { "piano", "guitar", "violin", "drums", "flute", "harp", "trumpet", "cello" },
	colors = { "crimson", "turquoise", "lavender", "amber", "ivory", "indigo", "scarlet", "emerald" },
	vehicles = { "bicycle", "submarine", "helicopter", "skateboard", "canoe", "rocket", "tractor", "sailboat" },
	professions = { "astronaut", "detective", "surgeon", "mechanic", "pilot", "chef", "librarian", "firefighter" },
	weather = { "tornado", "blizzard", "rainbow", "hurricane", "hailstorm", "drought", "monsoon", "thunder" },
	movies = { "titanic", "frozen", "inception", "jaws", "avatar", "aliens", "gladiator", "bambi" },
}

return table.freeze(Themes)
