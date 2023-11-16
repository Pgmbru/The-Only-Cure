local StaticData = require("TOC/StaticData")
local CommonMethods = require("TOC/CommonMethods")
---------------------------

--- Submodule to handle spawning the correct items after certain actions (ie: cutting a hand). LOCAL ONLY!
---@class ItemsHandler
local ItemsHandler = {}



--* Player Methods *--
---@class ItemsHandler.Player
ItemsHandler.Player = {}

---Returns the correct index for the textures of the amputation
---@param playerObj IsoPlayer
---@param isCicatrized boolean
---@return number
---@private
function ItemsHandler.Player.GetAmputationTexturesIndex(playerObj, isCicatrized)
    local textureString = playerObj:getHumanVisual():getSkinTexture()
    local isHairy = string.find(textureString, "a$")
    -- Hairy bodies
    if isHairy then
        textureString = textureString:sub(1, -2)      -- Removes b at the end to make it compatible
    end

    local matchedIndex = string.match(textureString, "%d$")

    -- TODO Rework this
    if isHairy then
        matchedIndex = matchedIndex + 5
    end


    if isCicatrized then
        if isHairy then
            matchedIndex = matchedIndex + 5           -- to use the cicatrized texture on hairy bodies
        else
            matchedIndex = matchedIndex + 10          -- cicatrized texture only, no hairs
        end
    end

    return matchedIndex - 1
end

---Main function to delete a clothing item
---@param playerObj IsoPlayer
---@param clothingItem InventoryItem?
---@return boolean
---@private
function ItemsHandler.Player.RemoveClothingItem(playerObj, clothingItem)
    if clothingItem and instanceof(clothingItem, "InventoryItem") then
        playerObj:removeWornItem(clothingItem)

        playerObj:getInventory():Remove(clothingItem)       -- Can be a InventoryItem too.. I guess? todo check it
        TOC_DEBUG.print("found and deleted" .. tostring(clothingItem))
        return true
    end
    return false
end

---Search and deletes an old amputation clothing item on the same side
---@param playerObj IsoPlayer
---@param limbName string
function ItemsHandler.Player.DeleteOldAmputationItem(playerObj, limbName)
    local side = CommonMethods.GetSide(limbName)
    for partName, _ in pairs(StaticData.PARTS_IND_STR) do
        local othLimbName = partName .. "_" .. side
        local othClothingItemName = StaticData.AMPUTATION_CLOTHING_ITEM_BASE .. othLimbName

        -- TODO FindAndReturn could return an ArrayList. We need to check for that
        local othClothingItem = playerObj:getInventory():FindAndReturn(othClothingItemName)


        -- If we manage to find and remove an item, then we should stop this function.
        ---@cast othClothingItem InventoryItem
        if ItemsHandler.Player.RemoveClothingItem(playerObj, othClothingItem) then return end
    end
end

---Deletes all the old amputation items, used for resets
---@param playerObj IsoPlayer
function ItemsHandler.Player.DeleteAllOldAmputationItems(playerObj)

    for i=1, #StaticData.LIMBS_STR do
        local limbName = StaticData.LIMBS_STR[i]
        local clothItemName = StaticData.AMPUTATION_CLOTHING_ITEM_BASE .. limbName
        local clothItem = playerObj:getInventory():FindAndReturn(clothItemName)
        ---@cast clothItem InventoryItem
        ItemsHandler.Player.RemoveClothingItem(playerObj, clothItem)
    end
end

---Spawns and equips the correct amputation item to the player.
---@param playerObj IsoPlayer
---@param limbName string
function ItemsHandler.Player.SpawnAmputationItem(playerObj, limbName)
    TOC_DEBUG.print("clothing name " .. StaticData.AMPUTATION_CLOTHING_ITEM_BASE .. limbName)
    local clothingItem = playerObj:getInventory():AddItem(StaticData.AMPUTATION_CLOTHING_ITEM_BASE .. limbName)
    local texId = ItemsHandler.Player.GetAmputationTexturesIndex(playerObj, false)

    ---@cast clothingItem InventoryItem
    clothingItem:getVisual():setTextureChoice(texId) -- it counts from 0, so we have to subtract 1
    playerObj:setWornItem(clothingItem:getBodyLocation(), clothingItem)
end



--* Zombie Methods *--
---@class ItemsHandler.Zombie
ItemsHandler.Zombie = {}

---comment
---@param zombie IsoZombie
function ItemsHandler.Zombie.SpawnAmputationItem(zombie)
    -- TODO Set texture ID
    local itemVisualsList = zombie:getItemVisuals()
    local ignoredLimbs = {}

    if itemVisualsList == nil then return end

    for i=0, itemVisualsList:size() - 1 do
        local itemVisual = itemVisualsList:get(i)

        -- TODO Check body location of item and deletes potential amputation to apply
        local clothingName = itemVisual:getClothingItemName()
        --print(clothingName)

        if clothingName and luautils.stringStarts(clothingName, StaticData.AMPUTATION_CLOTHING_ITEM_BASE) then
            TOC_DEBUG.print("added " .. clothingName .. " to ignoredLimbs")
            ignoredLimbs[clothingName] = clothingName
        end

    end

    -- TODO COnsider highest amputation
    local usableClothingAmputations = {}

    for i=1, #StaticData.LIMBS_STR do
        local limbName = StaticData.LIMBS_STR[i]
        local clothingName = StaticData.AMPUTATION_CLOTHING_ITEM_BASE .. limbName
        if ignoredLimbs[clothingName] == nil then
            table.insert(usableClothingAmputations, clothingName)
        end
    end

    -- TODO Random index
    local index = ZombRand(1, #usableClothingAmputations)

    local itemVisual = ItemVisual:new()
    itemVisual:setItemType(usableClothingAmputations[index])
    zombie:getItemVisuals():add(itemVisual)
    zombie:resetModelNextFrame()
end


--------------------------
--* Overrides *--

local og_ISInventoryPane_refreshContainer = ISInventoryPane.refreshContainer

---Get the list of items for the container and remove the reference to the amputation items
---@diagnostic disable-next-line: duplicate-set-field
function ISInventoryPane:refreshContainer()
    og_ISInventoryPane_refreshContainer(self)
    if TOC_DEBUG.disablePaneMod then return end
    for i=1, #self.itemslist do
        local cItem = self.itemslist[i]
        if cItem and cItem.cat == "Amputation" then
            TOC_DEBUG.print("Refreshing container - current item is an amputation, removing it from the list of the container")
            table.remove(self.itemslist, i)
        end
    end
end

return ItemsHandler