------------------------------------------------------------------------------
-- MarktioneerEX [1.0.1]
------------------------------------------------------------------------------
-- This is an updated and improved version of Fiote's Marktioneer addon
-- (https://github.com/fiote/ToS-Addons). Fixes include working "My Items",
-- compatibility with "Market Show Level" addon, ability to post undercut
-- items and other (mostly minor) things added/removed/modified. Enjoy!
------------------------------------------------------------------------------
-- 1.0.1 - Fix for the 17.10.2017 patch.
------------------------------------------------------------------------------

local addon_dev = "Kalafiorek";
local addon_name = "MARKTIONEEREX";
local addon_name_tag = "MarktioneerEX";
local addon_name_lower = string.lower(addon_name);

_G["ADDONS"] = _G["ADDONS"] or {};
_G["ADDONS"][addon_dev] = _G["ADDONS"][addon_dev] or {};
_G["ADDONS"][addon_dev][addon_name] = _G["ADDONS"][addon_dev][addon_name] or {};

local g = _G["ADDONS"][addon_dev][addon_name];

g.addon = nil;
g.frame = nil;
g.loaded = false;

local cwAPI = require("cwapi");

marktioneerex = {};
marktioneerex.fullscaning = false;
marktioneerex.timedone = 0;
marktioneerex.dumpButton = nil;
marktioneerex.outputname = '../addons/marktioneerex/data.json';
marktioneerex.myItems = {};
marktioneerex.newwidth = 200;
marktioneerex.refreshing = nil;

local log = cwAPI.util.log;
local alert = ui.SysMsg;

-- ======================================================
--	MARKET - SCAN ALL
-- ======================================================

function marktioneerex.getMaxPage()
	local frame = ui.GetFrame("market");
	local pagecontrol = GET_CHILD(frame, "pageControl", "ui::CPageController");		
	local maxpage = pagecontrol:GetMaxPage();
	return maxpage, frame;
end

function marktioneerex.requestPage(page)
	local market = ui.GetFrame('market');
	if (market == nil or market:IsVisible() == 0) then return; end

	marktioneerex.pgnow = page;
	marktioneerex.fullscaning = true;
	local maxpage, frame = marktioneerex.getMaxPage();
	if (page <= maxpage) then MARGET_FIND_PAGE(frame,page); end
end

function marktioneerex.writeFile()
	-- log('[MarktioneerEX] Reading done/stopped! Writing (not) file...');
	marktioneerex.fullscaning = false;
	-- log('[MarktioneerEX] Done.');
end

function marktioneerex.marketItemList(frame)
	local count = session.market.GetItemCount();

	if (marktioneerex.refreshing) then
		for i = 0 , count - 1 do		
			local marketItem = session.market.GetItemByIndex(i);
			local itemObj = GetIES(marketItem:GetObject());
			local itemid = itemObj.ClassID;
			marktioneerex.data[itemid] = nil;
		end
	end

	if (marktioneerex.fullscaning or marktioneerex.refreshing) then
		for i = 0 , count - 1 do		
			local marketItem = session.market.GetItemByIndex(i);
			local itemObj = GetIES(marketItem:GetObject());
			local itemid = itemObj.ClassID;
			local price = marketItem.sellPrice;
			local qtde = marketItem.count;

			if (not marktioneerex.data[itemid]) then
				marktioneerex.data[itemid] = {};
			end

			if (not marktioneerex.data[itemid][price]) then
				marktioneerex.data[itemid][price] = 0;
			end

			marktioneerex.data[itemid][price] = marktioneerex.data[itemid][price] + qtde;
		end
	end

	if (marktioneerex.refreshing) then
		marktioneerex.writeFile();
		marktioneerex.updateLastRefreshed();
		marktioneerex.refreshNext();
	end

	if (marktioneerex.fullscaning) then
		local next = marktioneerex.pgnow+1;
		local max = marktioneerex.getMaxPage();

		if (next == nil or max == nil) then return; end;

		if (next <= max) then 
			if (marktioneerex.fullscaning) then 
				local prDone = math.floor(next*100/max);
				if (prDone > marktioneerex.prDone) then
					if (prDone % 10 == 0) then
					    log('[MarktioneerEX] '..prDone..'%');
					end
					marktioneerex.prDone = prDone;
				end
				marktioneerex.dumpButton:SetText("{@st42}"..next.."/"..max.."{/}");
				marktioneerex.requestPage(next); 
			end
		else 
			log('[MarktioneerEX] 100%');
			marktioneerex.writeFile();
			imcSound.PlaySoundEvent("market buy");
			log('[MarktioneerEX] Finished scanning!');
		end
	end
end

function marktioneerex.readMarket()
	cwAPI.events.on('ON_MARKET_ITEM_LIST',marktioneerex.marketItemList,1); -- don't ask.
	log('[MarktioneerEX] Starting the scan...');
	marktioneerex.data = {};
	marktioneerex.pgnow = 0;
	marktioneerex.timedone = 0;
	marktioneerex.fullscaning = true;
	marktioneerex.requestPage(0);
end

-- ======================================================
--	MARKET - SCAN ITEM
-- ======================================================

function marktioneerex.updateLastRefreshed() 
	local myitems = ui.GetFrame('market_myitems');
	if (myitems == nil or myitems:IsVisible() == 0) then return; end

	local myItem = marktioneerex.itemRefresh;
	if (myItem) then
		myItem.btn:SetText("{@st49}Done!{/}");
		marktioneerex.updateItemRow(myItem);
	end
end

function marktioneerex.updateItemRow(myItem)
	local myitems = ui.GetFrame('market_myitems');
	if (myitems == nil or myitems:IsVisible() == 0) then return; end

	local marketData = marktioneerex.getMinimumData(myItem.itemID);
	if (marketData) then
		myItem.price = marketData.price;
		myItem.priceText = GET_MONEY_IMG(24)..' '..GetCommaedText(marketData.price)..' (x'..marketData.qtde..')';
	else 
		myItem.price = 0;
		myItem.priceText = 'N/A';
	end 
	if (myItem.priceCtrl) then myItem.priceCtrl:SetText(myItem.priceText); end
end

function marktioneerex_refreshItem(frame, btn, itemName, itemID)
	cwAPI.events.on('ON_MARKET_ITEM_LIST',marktioneerex.marketItemList,1); -- told you not to ask.
	local myitems = ui.GetFrame('market_myitems');
	if (myitems == nil or myitems:IsVisible() == 0) then return; end

	btn:SetEnable(0);
	local objItem = GetClassByType('Item',itemID);
	itemName = dictionary.ReplaceDicIDInCompStr(objItem.Name);	
	--cwAPI.util.log('[MarktioneerEX] '..itemName..' | ID: '..itemID); --for debugging
	local groupName = objItem.GroupName;
	if (groupName == 'None' or groupName == '') then groupName = 'ShowAll'; end
	--cwAPI.util.log('Group: '..groupName);	--for debugging
	local classType = objItem.ClassType;
	if (classType == 'None') then classType = ''; end
	--cwAPI.util.log('Class: '..classType); --for debugging
	marktioneerex.refreshing = true;
	market.ReqMarketList(0, itemName, groupName, classType, objItem.UseLv, objItem.UseLv, 0, 20, 0);
end

function marktioneerex_refreshAll(frame, btn)
	cwAPI.events.on('ON_MARKET_ITEM_LIST',marktioneerex.marketItemList,1); -- that's it, I'm calling the police.
	local myitems = ui.GetFrame('market_myitems');
	if (myitems == nil or myitems:IsVisible() == 0) then return; end

	marktioneerex.itemsRefresh = {};

	for i,myItem in pairs(marktioneerex.myItems) do
		table.insert(marktioneerex.itemsRefresh,myItem);
	end

	btn:SetEnable(0);
	
	local frame = ui.GetFrame('market_myitems');

	ui.MsgBox("Please don't interrupt the scanning...");
	-- if you have any ideas how to make it not destroy the universe and leak all teh RAMs, be my guest.
	-- error report here: https://github.com/fiote/ToS-Addons/issues/7

	for i,myItem in pairs(marktioneerex.itemsRefresh) do
		myItem.btn:SetEnable(0); 
	end

	marktioneerex.refreshNext();
end

function marktioneerex.refreshNext()
	local myitems = ui.GetFrame('market_myitems');
	if (myitems == nil or myitems:IsVisible() == 0) then return; end
	local btnAll = GET_CHILD_RECURSIVELY(myitems,'button_2');

	if (not marktioneerex.itemsRefresh) then
		marktioneerex.refreshDone();
	end

	local myItem = table.remove(marktioneerex.itemsRefresh,1);

	local total = #marktioneerex.myItems;
	local queued = #marktioneerex.itemsRefresh;
	local done = total - queued;

	if (myItem) then
		btnAll:SetText('{@st41b}'..done..' / '..total..'{/}');
		marktioneerex.itemRefresh = myItem;
		marktioneerex_refreshItem(nil, myItem.btn, nil, myItem.itemID); 
	else 
		marktioneerex.refreshDone();
	end
end

function marktioneerex.refreshDone() 
	local myitems = ui.GetFrame('market_myitems');
	if (myitems == nil or myitems:IsVisible() == 0) then return; end

	local btnAll = GET_CHILD_RECURSIVELY(myitems,'button_2');

	btnAll:SetText('{@st41b}Refresh All{/}');
	marktioneerex.itemRefresh = nil;
	marktioneerex.refreshing = false;
	btnAll:SetEnable(1);
	marktioneerex.createMyItemsFrame();
end

-- ======================================================
--	MARKET - SCAN BUTTON
-- ======================================================

function marktioneerex_clickButton()
	if (marktioneerex.fullscaning) then
		marktioneerex.fullscaning = true;
		marktioneerex.writeFile();
		marktioneerex.dumpButton:SetText("{@st42}Read Market{/}");
	else
		--log('[MarktioneerEX] Reading...');
		marktioneerex.prDone = 0;
		marktioneerex.dumpButton:SetText("{@st42}Reading...{/}");
		marktioneerex.readMarket();
	end
end

function marktioneerex.createReadMarketButton(frame)
	local ctrl = frame:CreateOrGetControl('button', 'marktioneerex_DUMP', 0, 0, 150, 30);
	tolua.cast(ctrl, 'ui::CCheckBox');
	ctrl:SetMargin(30, 60, 0, 70);
	ctrl:SetGravity(ui.RIGHT, ui.TOP);
	ctrl:Move(0,0);
	ctrl:SetOffset(20,110);
	ctrl:SetText("{@st42}Read Market{/}");
	ctrl:SetClickSound('button_click_big');
	ctrl:SetOverSound('button_over');
	ctrl:SetEventScript(ui.LBUTTONUP,'marktioneerex_clickButton()',true);
	marktioneerex.dumpButton = ctrl;
end

-- ======================================================
--	MARKET - MY ITEMS
-- ======================================================

function marktioneerex.sortByPrice(x,y)
	return x.price > y.price;
end

function marktioneerex.createMyItemsFrame()
	frame = ui.CreateNewFrame('market_cabinet','market_myitems');
	marktioneerex.adjustButtons();

	local btn = GET_CHILD_RECURSIVELY(frame,'button_1_1_1');
	btn:SetEventScript(ui.LBUTTONUP,'MARKET_CABINET_MODE', false);
	btn:SetSkinName('tab2_btn');

	local btnClose = GET_CHILD_RECURSIVELY(frame,'close');
	btnClose:SetEventScript(ui.LBUTTONUP,'marktioneerex_closeMyItems', false);

	-- TITLE
	local titleBox = GET_CHILD(frame,"title_1");
	titleBox:RemoveAllChild();

	local thPrice = titleBox:CreateOrGetControl('richtext', 'category_marketPrice', 10, 10, 100, 45);
	thPrice:SetGravity(ui.LEFT,ui.TOP);
	thPrice:SetOffset(680,10);
	thPrice:SetText('{@st45tw2} {/}');

	-- LIST
	local itemGbox = GET_CHILD(frame, "itemGbox");
	local itemlist = GET_CHILD(itemGbox, "itemlist", "ui::CDetailListBox");
	itemlist:RemoveAllChild();

	local btnAll = GET_CHILD_RECURSIVELY(frame,'button_2');
	btnAll:SetText('{@st41b}Refresh All{/}');	
	btnAll:SetEventScript(ui.LBUTTONUP, 'marktioneerex_refreshAll', false);
	btnAll:SetEnable(0);
	if (not marktioneerex.refreshing) then btnAll:SetEnable(1); end

	local cboxez = GET_CHILD_RECURSIVELY(frame,'buySuccessCheckbox');
	cboxez:ShowWindow(0);

	local cboxez = GET_CHILD_RECURSIVELY(frame,'sellSuccessCheckbox');
	cboxez:ShowWindow(0);

	local cboxez = GET_CHILD_RECURSIVELY(frame,'sellCancelCheckbox');
	cboxez:ShowWindow(0);

	local cboxez = GET_CHILD_RECURSIVELY(frame,'etcCheckbox');
	cboxez:ShowWindow(0);

	local invItemList = session.GetInvItemList();

	local tempList = {};

	local nrow = 0;
	local i = invItemList:Head();
	while 1 do
		if i == invItemList:InvalidIndex() then
			break;
		end
		local invItem = invItemList:Element(i);				
		local tempobj = invItem:GetObject();
		if tempobj ~= nil then
			local itemObj = GetIES(tempobj);
			local itemID = itemObj.ClassID;
			local GUID = invItem:GetIESID();

			local ok = true;

			-- Ignores listing items that break the script:
			-- [490125] Instanced Dungeon Multiply Token
			-- [668137] Magic Stone Fragments
			if (ok) then	
				if (itemID == 490125) or (itemID == 668137) then 
					ok = false; 
				end
			end

			if (ok) then
				if (itemObj.UserTrade ~= 'YES') then 
					ok = false; 
				end
			end

			if (ok) then
				local noTradeCnt = TryGetProp(itemObj, "BelongingCount");			
				if (noTradeCnt ~= nil and noTradeCnt >= invItem.count) then
					ok = false;
				end
			end

			if (ok) then
				if (cwSet) then
					for setName,setList in pairs(cwSet.sets) do
						for spotName,itemGuid in pairs(setList) do
							if (GUID == itemGuid) then
								ok = false;
							end
						end
					end
				end
			end

			if (ok) then
				local myTemp = {};
				myTemp.itemID = itemID;
				myTemp.guid = GUID;
				myTemp.invItem = invItem;
				myTemp.itemObj = itemObj;
				table.insert(tempList,myTemp);
				marktioneerex.updateItemRow(myTemp);
			end
		end
		i = invItemList:Next(i);		
	end

	table.sort(tempList,marktioneerex.sortByPrice);

	marktioneerex.myItems = {};

	for nrow, myTemp in pairs(tempList) do
		local invItem = myTemp.invItem;
		local itemObj = myTemp.itemObj;
		local itemID = myTemp.itemID;
		local GUID = myTemp.guid;

		local ctrlSet = INSERT_CONTROLSET_DETAIL_LIST(itemlist, nrow, 0, "market_cabinet_item_detail");
		ctrlSet:Resize(1370, ctrlSet:GetHeight());

		local pic = GET_CHILD(ctrlSet, "pic", "ui::CPicture");
		pic:SetImage(itemObj.Icon);

		local buyb = ctrlSet:GetChild("buyBox");
		buyb:ShowWindow(0);

		local etcb = ctrlSet:GetChild("etcBox");
		etcb:ShowWindow(0);

		local timb = ctrlSet:GetChild("timeBox");
		timb:ShowWindow(0);

		local prib = ctrlSet:GetChild("priceBox");
		prib:ShowWindow(0);

		local name = ctrlSet:GetChild("name");
		name:SetTextByKey("value","{s18}"..GET_FULL_NAME(itemObj).."{/}");
		name:SetOffset(name:GetX() + 10, name:GetY());	
		name:SetOffset(210,22);

		local count = ctrlSet:CreateControl("richtext", "txt_count" .. GUID, 650, 21, 0, 0);
		count:SetFontName("brown_18_b");
		count:SetText("{s15}Amount: {/}{s20}({/}{s17}"..invItem.count.."{/}{s20}){/}");

		local totalPrice = ctrlSet:CreateControl("richtext", "txt_totalPrice" .. GUID, 850, 21, 0, 0);
		totalPrice:SetFontName("brown_18_b");

		--local totalPrice = ctrlSet:GetChild("totalPrice");
		--totalPrice:SetTextByKey("value", 0);
		--totalPrice:SetOffset(totalPrice:GetX() - 25, totalPrice:GetY());
		--totalPrice:ShowWindow(1);

		--local minPrice = ctrlSet:GetChild("endTime");
		--minPrice:ShowWindow(0);

		local btn = GET_CHILD(ctrlSet, "btn");
		btn:ShowWindow(0);

		local btn = ctrlSet:CreateOrGetControl('button', 'market_myitems_sell'..GUID, 10, 10, 100, 45);
		btn:SetGravity(ui.RIGHT, ui.TOP);
		btn:SetOffset(10,10);
		btn:SetText("{@st49}Sell{/}");
		btn:SetSkinName('test_gray_button');
		btn:SetAnimation("MouseOnAnim", "btn_mouseover");
		btn:SetAnimation("MouseOffAnim", "btn_mouseoff");
		btn:SetEventScript(ui.LBUTTONUP, 'marktioneerex_sellMyItem', false);
		btn:SetUserValue("GUID",GUID);

		local btn = ctrlSet:CreateOrGetControl('button', 'market_myitems_refresh'..GUID, 10, 10, 100, 45);
		btn:SetGravity(ui.RIGHT, ui.TOP);
		btn:SetOffset(110,10);
		btn:SetText("{@st49}Refresh{/}");
		btn:SetSkinName('test_gray_button');
		btn:SetAnimation("MouseOnAnim", "btn_mouseover");
		btn:SetAnimation("MouseOffAnim", "btn_mouseoff");
		btn:SetEventScript(ui.LBUTTONUP, 'marktioneerex_refreshItem', false);
		btn:SetEventScriptArgString(ui.LBUTTONUP,'');
		btn:SetEventScriptArgNumber(ui.LBUTTONUP,itemID);
		btn:SetUserValue("itemID", itemID);
		btn:SetEnable(1);

		SET_ITEM_TOOLTIP_ALL_TYPE(ctrlSet, invItem, itemObj.ClassName, 'market', invItem.type, 0);

		local myItem = {};
		myItem.btn = btn;
		myItem.priceCtrl = totalPrice;
		myItem.guid = GUID;
		myItem.itemID = itemID;
		table.insert(marktioneerex.myItems,myItem);

		marktioneerex.updateItemRow(myItem);
	end

	GBOX_AUTO_ALIGN(itemlist, 10, 0, 0, true, true);	
end

function marktioneerex_openMyItems()
	marktioneerex.createMyItemsFrame();
	ui.CloseFrame('market');
	ui.CloseFrame('market_sell');
	ui.CloseFrame('market_cabinet');
end

function marktioneerex_closeMyItems()
	ui.CloseFrame('market_myitems');
end

function marktioneerex.createMyItemsButton(frame,left)
	local ctrl = frame:CreateOrGetControl('button','marktioneerex_MYITEMS_'..frame:GetName(), 0, 0, marktioneerex.newwidth, 45);
	ctrl:SetGravity(ui.RIGHT, ui.TOP);
	ctrl:Move(0,0);
	ctrl:SetOffset(left+5,105);
	ctrl:SetSkinName('tab2_btn');
	ctrl:SetClickSound('button_click');
	ctrl:SetOverSound('button_over');
	ctrl:SetText("{@st66b18}My Items{/}");
	ctrl:SetEventScript(ui.LBUTTONUP,'marktioneerex_openMyItems()',true);
	return left + marktioneerex.newwidth;
end

-- ======================================================
--	MARKET - UI
-- ======================================================

function marktioneerex.adjustButtons()	
	local list = {};
	table.insert(list,{frame = ui.GetFrame('market'), controls = {'marketBuy','marketSell','marketCabinet'}});	
	table.insert(list,{frame = ui.GetFrame('market_sell'), controls = {'button_1','button_1_2','button_1_2_1'}});	
	table.insert(list,{frame = ui.GetFrame('market_cabinet'), controls = {'button_1','button_1_1','button_1_1_1'}});	
	table.insert(list,{frame = ui.GetFrame('market_myitems'), controls = {'button_1','button_1_1','button_1_1_1'}});	

	for i,entry in pairs(list) do
		if (entry.frame) then
			local left = 10;
			
			for j,cname in pairs(entry.controls) do
				local ctrl = entry.frame:GetChildRecursively(cname);
				local text = ctrl:GetText();
				ctrl:Resize(marktioneerex.newwidth,45);
				ctrl:SetGravity(ui.LEFT, ui.TOP);
				ctrl:Move(0,0);
				ctrl:SetOffset(left,105);				
				ctrl:SetTextAlign('left','center');
				ctrl:SetTextAlign('center','center');
				entry.frame:Invalidate();
				left = left + marktioneerex.newwidth;
			end

			left = marktioneerex.createMyItemsButton(entry.frame,left);
		end
	end
end

function marktioneerex.adjustMarketUI()
	local frame = ui.GetFrame('market');
	if (not frame) then return; end	
	marktioneerex.createReadMarketButton(frame);	
	marktioneerex.adjustButtons();
end

function marktioneerex.enterAnyMode()
	marktioneerex.adjustMarketUI();
	ui.CloseFrame('market_myitems');
end

-- ======================================================
--	GET DATA
-- ======================================================

function marktioneerex.getMinimumData(itemID) 
	local values = marktioneerex.data[itemID];	
	if (values) then

		local aslist = {};
		for price,qty in pairs(values) do
			local data = {};
			data.price = tonumber(price);
			data.qtde = tonumber(qty);
			table.insert(aslist,data);
		end

		table.sort(aslist,marktioneerex.sortPrice);
		local cls = GetClassByType('Item',itemID);

		for i,data in pairs(aslist) do
			if (i == 1) then return data; end
		end
	end

	return nil;	
end

-- ======================================================
--	cwFarmed integration
-- ======================================================

function marktioneerex.cwFarmedCall(itemID)
	local data = marktioneerex.getMinimumData(itemID);
	if (data) then return marktioneerex.getTextData(data); end
	return '';
end

-- ======================================================
--	TOOLTIPS
-- ======================================================

function marktioneerex.sortPrice(a,b) 
	return a.price < b.price;
end

function marktioneerex.getTextData(data)
	return GET_MONEY_IMG(24).." {@st66b}"..GetCommaedText(data.price).."{/} {@st66}(x"..GetCommaedText(data.qtde)..").{/} ";
end

function marktioneerex.addMarketPrice(tooltipFrame, mainFrameName, invItem, strArg, useSubFrame)

	local gBox = GET_CHILD(tooltipFrame, mainFrameName,'ui::CGroupBox');    
    local yPos = gBox:GetY() + gBox:GetHeight();    

    local ctrl = gBox:CreateOrGetControl("richtext", 'marketprice', 0, yPos, 350, 30);

    tolua.cast(ctrl, "ui::CRichText");

	local text = '';
	
	local newRows = 2;
	local itemID = invItem.ClassID;
	local values = marktioneerex.data[itemID];
	local headText = "{@st42b}----------------------------------------------------{/}{nl}"
	text = text .. "{nl}"..headText;

	if (values) then
		local aslist = {};
		for price,qty in pairs(values) do
			local data = {};
			data.price = tonumber(price);
			data.qtde = tonumber(qty);
			table.insert(aslist,data);
		end

		table.sort(aslist,marktioneerex.sortPrice);

		for i,data in pairs(aslist) do
			if (i <= 3) then
				text = text .. marktioneerex.getTextData(data);
			end
		end
	else 
		text = text .. GET_MONEY_IMG(24) .. " {@st67b}No market info available.{/}";
	end

    ctrl:SetText(text);
    ctrl:SetMargin(20,gBox:GetHeight() - 15,0,0)

    local BOTTOM_MARGIN = tooltipFrame:GetUserConfig("BOTTOM_MARGIN");
    gBox:Resize(gBox:GetWidth(),gBox:GetHeight() + ctrl:GetHeight());
    
    return ctrl:GetHeight() + ctrl:GetY();
end

function marktioneerex.drawTooltipEQUIP(tooltipFrame, invItem, strArg, useSubFrame)
	local fn = cwAPI.events.original('ITEM_TOOLTIP_EQUIP');
	yPos = fn(tooltipFrame, invItem, strArg, useSubFrame);
    
    local mainFrameName = 'equip_main'
    local addInfoFrameName = 'equip_main_addinfo'
    local drawNowEquip = 'true'
    
    if useSubFrame == "usesubframe" then
        mainFrameName = 'equip_sub'
        addInfoFrameName = 'equip_sub_addinfo'
    elseif useSubFrame == "usesubframe_recipe" then
        mainFrameName = 'equip_sub'
        addInfoFrameName = 'equip_sub_addinfo'
        drawNowEquip = 'false'
    end
    
    return marktioneerex.addMarketPrice(tooltipFrame, mainFrameName, invItem, strArg, useSubFrame);  
end

function marktioneerex.drawTooltipETC(tooltipFrame, invItem, strArg, useSubFrame)

	local fn = cwAPI.events.original('ITEM_TOOLTIP_ETC');
	yPos = fn(tooltipFrame, invItem, strArg, useSubFrame);

	local mainFrameName = 'etc'
    
    if useSubFrame == "usesubframe" then
      mainFrameName = "etc_sub"
    elseif useSubFrame == "usesubframe_recipe" then
      mainFrameName = "etc_sub"
    end    

    return marktioneerex.addMarketPrice(tooltipFrame, mainFrameName, invItem, strArg, useSubFrame);    
end

-- ======================================================
--	ON SELLING
-- ======================================================

function marktioneerex_sellMyItem(frame, btn, strArg, numArg)
	local GUID = btn:GetUserValue('GUID');
	MARKET_SELLMODE();
	local frame = ui.GetFrame('market_sell');
	local invItem = session.GetInvItemByGuid(GUID);
	MARKET_SELL_RBUTTON_ITEM_CLICK(frame,invItem);
end

function marktioneerex.getUndercutPrice(price)
	local strprice = ''..(price);

	if string.len(strprice) < 3 then
		return 100;
	end

	local floorprice = strprice.sub(strprice,0,2);
	for i = 0 , string.len(strprice) - 3 do
		floorprice = floorprice .. "0";
	end

	return tonumber(floorprice);
end

function marktioneerex.setMyValue(frame,minAllow)
	if (not minAllow) then minAllow = 0; end

	local groupbox = frame:GetChild("groupbox");
	local slotItem = GET_CHILD(groupbox, "slot_item", "ui::CSlot");
	local item = GET_SLOT_ITEM(slotItem);
	if (not item) then return end;
	
	local itemObj = GetIES(item:GetObject());
	local itemID = itemObj.ClassID;

	local priceTitle = GET_CHILD(groupbox,"richtext_2_1","ui::CRichText");
	priceTitle:SetText("Unit Price");
	priceTitle:Resize(200,priceTitle:GetHeight());

	local data = marktioneerex.getMinimumData(itemID);
	if (data) then 
		local myprice = marktioneerex.getUndercutPrice(data.price);
		local edit_price = GET_CHILD(groupbox, "edit_price", "ui::CEditControl");
		if (myprice < minAllow) then			
			--ui.MsgBox("{img "..itemObj.Icon.." 50 50} {@sti5}"..itemObj.Name.."{/}{nl}{nl}Can't undercut to "..GetCommaedText(myprice)..".{nl}Market underlimit is too low.");
			edit_price:SetText(myprice);
		else 
			priceTitle:SetText("Unit Price (1z undercut)");
			edit_price:SetText(myprice);
		end
	end
end

function marktioneerex.afterMinMaxValue(frame, msg, argStr, argNum)
	if argNum == 1 then		
		local tokenList = TokenizeByChar(argStr, ";");
		local minAllow = math.floor(tokenList[2]);
		marktioneerex.setMyValue(frame,minAllow);
	end
end

-- ======================================================
--	LOADER
-- ======================================================

function MARKTIONEEREX_ON_INIT(addon, frame)
	g.addon = addon;
	g.frame = frame;
	if g.loaded == false then
		-- checking dependences
		if (not cwAPI) then
			ui.SysMsg('[MarktioneerEX] requires cwAPI to run.');
			return false;
		end
		
		-- executing onload
		-- marktioneerex.data = cwAPI.json.load('marktioneerex','values');

		if (not marktioneerex.data) then marktioneerex.data = {}; end
		if (not marktioneerex.sells) then marktioneerex.sells = {}; end

		cwAPI.events.on('ON_OPEN_MARKET',marktioneerex.adjustMarketUI,1);
		cwAPI.events.on('MARKET_BUYMODE',marktioneerex.enterAnyMode,1);
		cwAPI.events.on('MARKET_SELLMODE',marktioneerex.enterAnyMode,1);
		cwAPI.events.on('MARKET_CABINET_MODE',marktioneerex.enterAnyMode,1);

		cwAPI.events.on('ON_MARKET_ITEM_LIST',marktioneerex.marketItemList,1);
		cwAPI.events.on('ON_OPEN_MARKET',marktioneerex.marketItemList,1);

		cwAPI.events.on('ITEM_TOOLTIP_ETC',marktioneerex.drawTooltipETC,0);
		cwAPI.events.on('ITEM_TOOLTIP_EQUIP',marktioneerex.drawTooltipEQUIP,0);

		cwAPI.events.on('MARKET_SELL_UPDATE_SLOT_ITEM',marktioneerex.setMyValue,1);
		cwAPI.events.on('ON_MARKET_MINMAX_INFO',marktioneerex.afterMinMaxValue,1);	

		g.loaded = true;

		cwAPI.util.log('[MarktioneerEX] loaded.');
	end
end