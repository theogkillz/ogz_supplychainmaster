-- OX_ITEMS.LUA - COMPLETE REIGN_ TO OGZ_ CONVERSION
-- Professional item ecosystem for manufacturing integration

return {
	-- ==============================================
	-- RAW FARMING MATERIALS
	-- ==============================================
	
	-- Grains & Cereals
	['ogz_wheat_seeds'] = {
		label = 'Wheat Seeds',
		weight = 50,
		stack = true,
		close = true,
		description = 'Premium wheat seeds for farming'
	},
	
	['ogz_wheat_plant'] = {
		label = 'Wheat Plant',
		weight = 200,
		stack = true,
		close = true,
		description = 'Fresh wheat plant ready for processing'
	},
	
	['ogz_rice_seeds'] = {
		label = 'Rice Seeds',
		weight = 30,
		stack = true,
		close = true,
		description = 'High-quality rice seeds'
	},
	
	['ogz_rice_plant'] = {
		label = 'Rice Plant',
		weight = 180,
		stack = true,
		close = true,
		description = 'Fresh rice plant for flour production'
	},
	
	-- ==============================================
	-- PROCESSED INGREDIENTS (MANUFACTURED)
	-- ==============================================
	
	-- Flour Products (Manufacturing Output)
	['ogz_flour_basic'] = {
		label = 'Basic Flour',
		weight = 500,
		stack = true,
		close = true,
		description = 'Basic flour for standard recipes',
		created = 'Manufacturing Process'
	},
	
	['ogz_flour_premium'] = {
		label = 'Premium Flour',
		weight = 500,
		stack = true,
		close = true,
		description = 'Premium flour blend for gourmet cooking',
		created = 'Advanced Manufacturing'
	},
	
	['ogz_flour_specialty'] = {
		label = 'Specialty Flour',
		weight = 500,
		stack = true,
		close = true,
		description = 'Specialty flour for unique recipes',
		created = 'Expert Manufacturing'
	},
	
	-- ==============================================
	-- MEAT PRODUCTS
	-- ==============================================
	
	-- Raw Livestock
	['ogz_livestock_cow'] = {
		label = 'Live Cow',
		weight = 5000,
		stack = false,
		close = true,
		description = 'Live cow for meat and dairy production'
	},
	
	['ogz_livestock_pig'] = {
		label = 'Live Pig',
		weight = 3000,
		stack = false,
		close = true,
		description = 'Live pig for pork production'
	},
	
	['ogz_livestock_chicken'] = {
		label = 'Live Chicken',
		weight = 800,
		stack = true,
		close = true,
		description = 'Live chicken for poultry production'
	},
	
	-- Processed Meats (Manufacturing Output)
	['ogz_ground_beef'] = {
		label = 'Ground Beef',
		weight = 250,
		stack = true,
		close = true,
		description = 'Fresh ground beef for cooking',
		created = 'Meat Processing Plant'
	},
	
	['ogz_ground_pork'] = {
		label = 'Ground Pork',
		weight = 250,
		stack = true,
		close = true,
		description = 'Fresh ground pork for recipes',
		created = 'Meat Processing Plant'
	},
	
	['ogz_ground_chicken'] = {
		label = 'Ground Chicken',
		weight = 200,
		stack = true,
		close = true,
		description = 'Fresh ground chicken for cooking',
		created = 'Poultry Processing'
	},
	
	['ogz_ground_blend'] = {
		label = 'Premium Ground Blend',
		weight = 300,
		stack = true,
		close = true,
		description = 'Premium meat blend for gourmet recipes',
		created = 'Advanced Meat Processing'
	},
	
	-- Packaged Meats (Ready for Delivery)
	['ogz_packed_groundmeat'] = {
		label = 'Packaged Ground Meat',
		weight = 300,
		stack = true,
		close = true,
		description = 'Vacuum-sealed ground meat ready for delivery'
	},
	
	['ogz_packed_groundchicken'] = {
		label = 'Packaged Ground Chicken',
		weight = 250,
		stack = true,
		close = true,
		description = 'Vacuum-sealed ground chicken for restaurants'
	},
	
	['ogz_packed_groundpork'] = {
		label = 'Packaged Ground Pork',
		weight = 280,
		stack = true,
		close = true,
		description = 'Vacuum-sealed ground pork for commercial use'
	},
	
	-- ==============================================
	-- DAIRY PRODUCTS
	-- ==============================================
	
	-- Raw Dairy
	['ogz_milk_cow'] = {
		label = 'Fresh Cow Milk',
		weight = 1000,
		stack = true,
		close = true,
		description = 'Fresh milk from grass-fed cows'
	},
	
	['ogz_milk_goat'] = {
		label = 'Fresh Goat Milk',
		weight = 800,
		stack = true,
		close = true,
		description = 'Premium goat milk for specialty products'
	},
	
	-- Processing Cultures
	['ogz_cultures_cheese'] = {
		label = 'Cheese Cultures',
		weight = 50,
		stack = true,
		close = true,
		description = 'Bacterial cultures for cheese making'
	},
	
	['ogz_cultures_yogurt'] = {
		label = 'Yogurt Cultures',
		weight = 50,
		stack = true,
		close = true,
		description = 'Live cultures for yogurt production'
	},
	
	-- Processed Dairy (Manufacturing Output)
	['ogz_cheese_block'] = {
		label = 'Cheese Block',
		weight = 1000,
		stack = true,
		close = true,
		description = 'Aged cheese block ready for slicing',
		created = 'Dairy Manufacturing'
	},
	
	['ogz_cheese_artisan'] = {
		label = 'Artisan Cheese',
		weight = 800,
		stack = true,
		close = true,
		description = 'Premium artisan cheese for fine dining',
		created = 'Artisan Dairy Process'
	},
	
	['ogz_butter_fresh'] = {
		label = 'Fresh Butter',
		weight = 500,
		stack = true,
		close = true,
		description = 'Freshly churned butter for cooking',
		created = 'Dairy Manufacturing'
	},
	
	-- Packaged Dairy (Ready for Delivery)
	['ogz_packed_cheese'] = {
		label = 'Packaged Cheese',
		weight = 400,
		stack = true,
		close = true,
		description = 'Vacuum-sealed cheese portions for restaurants'
	},
	
	['ogz_packed_butter'] = {
		label = 'Packaged Butter',
		weight = 300,
		stack = true,
		close = true,
		description = 'Commercial butter packaging for kitchen use'
	},
	
	-- ==============================================
	-- VEGETABLES & PRODUCE
	-- ==============================================
	
	-- Fresh Vegetables
	['ogz_tomato_fresh'] = {
		label = 'Fresh Tomatoes',
		weight = 150,
		stack = true,
		close = true,
		description = 'Vine-ripened tomatoes for cooking'
	},
	
	['ogz_lettuce_fresh'] = {
		label = 'Fresh Lettuce',
		weight = 120,
		stack = true,
		close = true,
		description = 'Crisp lettuce for salads and burgers'
	},
	
	['ogz_onion_fresh'] = {
		label = 'Fresh Onions',
		weight = 180,
		stack = true,
		close = true,
		description = 'Farm-fresh onions for flavoring'
	},
	
	['ogz_potato_fresh'] = {
		label = 'Fresh Potatoes',
		weight = 200,
		stack = true,
		close = true,
		description = 'High-quality potatoes for cooking'
	},
	
	-- Processed Vegetables (Manufacturing Output)
	['ogz_tomato_paste'] = {
		label = 'Tomato Paste',
		weight = 400,
		stack = true,
		close = true,
		description = 'Concentrated tomato paste for sauces',
		created = 'Vegetable Processing'
	},
	
	['ogz_onion_diced'] = {
		label = 'Diced Onions',
		weight = 250,
		stack = true,
		close = true,
		description = 'Pre-diced onions for commercial kitchens',
		created = 'Vegetable Processing'
	},
	
	['ogz_potato_fries'] = {
		label = 'Pre-cut Fries',
		weight = 300,
		stack = true,
		close = true,
		description = 'Pre-cut potato fries ready for cooking',
		created = 'Potato Processing'
	},
	
	-- ==============================================
	-- SPECIALTY INGREDIENTS
	-- ==============================================
	
	-- Seasonings & Spices
	['ogz_salt_coarse'] = {
		label = 'Coarse Salt',
		weight = 100,
		stack = true,
		close = true,
		description = 'Natural coarse salt for seasoning'
	},
	
	['ogz_salt_fine'] = {
		label = 'Fine Salt',
		weight = 100,
		stack = true,
		close = true,
		description = 'Fine table salt for cooking'
	},
	
	['ogz_pepper_black'] = {
		label = 'Black Pepper',
		weight = 50,
		stack = true,
		close = true,
		description = 'Freshly ground black pepper'
	},
	
	['ogz_herbs_mixed'] = {
		label = 'Mixed Herbs',
		weight = 30,
		stack = true,
		close = true,
		description = 'Dried herb mixture for seasoning'
	},
	
	-- Oils & Fats
	['ogz_oil_vegetable'] = {
		label = 'Vegetable Oil',
		weight = 800,
		stack = true,
		close = true,
		description = 'High-quality vegetable oil for cooking'
	},
	
	['ogz_oil_olive'] = {
		label = 'Olive Oil',
		weight = 500,
		stack = true,
		close = true,
		description = 'Extra virgin olive oil for premium dishes'
	},
	
	-- ==============================================
	-- MANUFACTURING EQUIPMENT & CONTAINERS
	-- ==============================================
	
	-- Processing Equipment
	['ogz_grinder_manual'] = {
		label = 'Manual Grinder',
		weight = 5000,
		stack = false,
		close = true,
		description = 'Manual grinder for small-scale processing'
	},
	
	['ogz_grinder_electric'] = {
		label = 'Electric Grinder',
		weight = 8000,
		stack = false,
		close = true,
		description = 'Electric grinder for efficient processing'
	},
	
	['ogz_press_cheese'] = {
		label = 'Cheese Press',
		weight = 12000,
		stack = false,
		close = true,
		description = 'Professional cheese press for dairy production'
	},
	
	-- Packaging Materials
	['ogz_container_small'] = {
		label = 'Small Container',
		weight = 100,
		stack = true,
		close = true,
		description = 'Small plastic container for ingredient storage'
	},
	
	['ogz_container_medium'] = {
		label = 'Medium Container',
		weight = 150,
		stack = true,
		close = true,
		description = 'Medium container for bulk ingredients'
	},
	
	['ogz_container_large'] = {
		label = 'Large Container',
		weight = 200,
		stack = true,
		close = true,
		description = 'Large container for industrial quantities'
	},
	
	-- Vacuum Seal Bags
	['ogz_vacuum_bag_small'] = {
		label = 'Small Vacuum Bag',
		weight = 10,
		stack = true,
		close = true,
		description = 'Small vacuum-seal bag for packaging'
	},
	
	['ogz_vacuum_bag_large'] = {
		label = 'Large Vacuum Bag',
		weight = 20,
		stack = true,
		close = true,
		description = 'Large vacuum-seal bag for bulk items'
	},
	
	-- ==============================================
	-- FRUITS & SWEET PRODUCTS
	-- ==============================================
	
	-- Fresh Fruits
	['ogz_apple_fresh'] = {
		label = 'Fresh Apples',
		weight = 150,
		stack = true,
		close = true,
		description = 'Crisp apples for desserts and cooking'
	},
	
	['ogz_strawberry_fresh'] = {
		label = 'Fresh Strawberries',
		weight = 120,
		stack = true,
		close = true,
		description = 'Sweet strawberries for desserts'
	},
	
	['ogz_banana_fresh'] = {
		label = 'Fresh Bananas',
		weight = 140,
		stack = true,
		close = true,
		description = 'Ripe bananas for baking and smoothies'
	},
	
	-- Processed Fruits (Manufacturing Output)
	['ogz_apple_sauce'] = {
		label = 'Apple Sauce',
		weight = 300,
		stack = true,
		close = true,
		description = 'Smooth apple sauce for desserts',
		created = 'Fruit Processing'
	},
	
	['ogz_strawberry_jam'] = {
		label = 'Strawberry Jam',
		weight = 250,
		stack = true,
		close = true,
		description = 'Homemade strawberry jam for pastries',
		created = 'Fruit Processing'
	},
	
	-- ==============================================
	-- PREPARED INGREDIENTS (RESTAURANT READY)
	-- ==============================================
	
	-- Ready-to-Cook Proteins
	['ogz_patty_raw'] = {
		label = 'Raw Meat Patty',
		weight = 200,
		stack = true,
		close = true,
		description = 'Formed meat patty ready for cooking'
	},
	
	['ogz_chicken_breast'] = {
		label = 'Chicken Breast',
		weight = 300,
		stack = true,
		close = true,
		description = 'Boneless chicken breast for grilling'
	},
	
	-- Prepared Vegetables
	['ogz_lettuce_shredded'] = {
		label = 'Shredded Lettuce',
		weight = 100,
		stack = true,
		close = true,
		description = 'Pre-shredded lettuce for quick service'
	},
	
	['ogz_tomato_sliced'] = {
		label = 'Sliced Tomatoes',
		weight = 120,
		stack = true,
		close = true,
		description = 'Pre-sliced tomatoes for burgers'
	},
	
	-- Cheese Products
	['ogz_cheese_slice'] = {
		label = 'Cheese Slices',
		weight = 150,
		stack = true,
		close = true,
		description = 'Pre-sliced cheese for melting'
	},
	
	['ogz_cheese_shredded'] = {
		label = 'Shredded Cheese',
		weight = 200,
		stack = true,
		close = true,
		description = 'Shredded cheese for toppings'
	},
	
	-- ==============================================
	-- ADVANCED PROCESSED GOODS
	-- ==============================================
	
	-- Sauces & Condiments (Manufacturing Output)
	['ogz_sauce_bbq'] = {
		label = 'BBQ Sauce',
		weight = 300,
		stack = true,
		close = true,
		description = 'House-made BBQ sauce for grilling',
		created = 'Sauce Manufacturing'
	},
	
	['ogz_sauce_ranch'] = {
		label = 'Ranch Dressing',
		weight = 250,
		stack = true,
		close = true,
		description = 'Creamy ranch dressing for salads',
		created = 'Sauce Manufacturing'
	},
	
	['ogz_mayo_fresh'] = {
		label = 'Fresh Mayonnaise',
		weight = 200,
		stack = true,
		close = true,
		description = 'Freshly made mayonnaise for sandwiches',
		created = 'Sauce Manufacturing'
	},
	
	-- Baking Ingredients (Manufacturing Output)
	['ogz_dough_pizza'] = {
		label = 'Pizza Dough',
		weight = 400,
		stack = true,
		close = true,
		description = 'Fresh pizza dough ready for toppings',
		created = 'Bakery Manufacturing'
	},
	
	['ogz_dough_bread'] = {
		label = 'Bread Dough',
		weight = 500,
		stack = true,
		close = true,
		description = 'Bread dough for fresh loaves',
		created = 'Bakery Manufacturing'
	},
	
	['ogz_batter_pancake'] = {
		label = 'Pancake Batter',
		weight = 300,
		stack = true,
		close = true,
		description = 'Pre-mixed pancake batter for breakfast',
		created = 'Batter Manufacturing'
	},
	
	-- ==============================================
	-- QUALITY GRADES & SPECIALTY ITEMS
	-- ==============================================
	
	-- Premium Grade Ingredients
	['ogz_beef_prime'] = {
		label = 'Prime Grade Beef',
		weight = 800,
		stack = true,
		close = true,
		description = 'Premium prime grade beef for fine dining',
		grade = 'Prime'
	},
	
	['ogz_cheese_aged'] = {
		label = 'Aged Cheese',
		weight = 600,
		stack = true,
		close = true,
		description = 'Aged cheese with complex flavors',
		grade = 'Premium'
	},
	
	['ogz_flour_organic'] = {
		label = 'Organic Flour',
		weight = 500,
		stack = true,
		close = true,
		description = 'Certified organic flour for health-conscious cooking',
		grade = 'Organic'
	},
	
	-- Specialty Manufacturing Tools
	['ogz_thermometer_digital'] = {
		label = 'Digital Thermometer',
		weight = 200,
		stack = false,
		close = true,
		description = 'Precision digital thermometer for manufacturing'
	},
	
	['ogz_scale_precision'] = {
		label = 'Precision Scale',
		weight = 1000,
		stack = false,
		close = true,
		description = 'Precision scale for accurate ingredient measurement'
	},
	
	-- Quality Control Items
	['ogz_test_kit_ph'] = {
		label = 'pH Test Kit',
		weight = 100,
		stack = true,
		close = true,
		description = 'pH testing kit for dairy and sauce production'
	},
	
	['ogz_test_kit_moisture'] = {
		label = 'Moisture Test Kit',
		weight = 150,
		stack = true,
		close = true,
		description = 'Moisture content testing for flour and grains'
	}
}