--!strict

local Themes: { [string]: { string } } = {
  animals = { "cat", "dog", "elephant", "parrot", "dolphin", "penguin" },
  food = { "pizza", "sushi", "croissant", "burger", "ramen", "tacos" },
  sports = { "soccer", "tennis", "basketball", "swimming", "fencing", "rugby" },
  countries = { "france", "japan", "brazil", "canada", "egypt", "iceland" },
  instruments = { "piano", "guitar", "violin", "drums", "flute", "harp" },
  colors = { "crimson", "turquoise", "lavender", "amber", "ivory", "indigo" },
  -- TODO: load additional themes from a datastore
}

return table.freeze(Themes)
