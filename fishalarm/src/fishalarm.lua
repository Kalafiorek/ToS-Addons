------------------------------------------------------------------------------
-- FishAlarm [1.0.0]
------------------------------------------------------------------------------
-- Makes a sound and "alt+tab switches" window focus to Tree of Savior
-- after player hits his/hers account limit of daily fishing tries
-- or fills the tackle box (useful when buying slots becomes possible)
------------------------------------------------------------------------------

local addon_dev = "Kalafiorek";
local addon_name = "FISHALARM";
local addon_name_tag = "FishAlarm";
local addon_name_lower = string.lower(addon_name);

_G["ADDONS"] = _G["ADDONS"] or {};
_G["ADDONS"][addon_dev] = _G["ADDONS"][addon_dev] or {};
_G["ADDONS"][addon_dev][addon_name] = _G["ADDONS"][addon_dev][addon_name] or {};

local g = _G["ADDONS"][addon_dev][addon_name];

g.addon = nil;
g.frame = nil;
g.loaded = false;

faSwitchDisabled = false;
faCtrl = nil;


function FISHALARM_UI(frame, msg, argStr, argNum)
	_G["ON_FISHING_ITEM_LIST_OLDE"](frame, msg, argStr, argNum);

------------------------------------------------------------------------------
-- Things addon needs to rule the world
------------------------------------------------------------------------------

	local account = session.barrack.GetMyAccount();
    local accountObj = GetMyAccountObj();
    local curSuccessCount = TryGetProp(accountObj, 'FishingSuccessCount');
    local maxSuccessCount = SCR_GET_MAX_FISHING_SUCCESS_COUNT(GetMyPCObject());

------------------------------------------------------------------------------
-- Sexy checkbox creation process (parental advisory, explicit content)
------------------------------------------------------------------------------

	faCtrl = frame:CreateOrGetControl('checkbox', 'FISHALARM_SWITCHER', 0, 0, 150, 30);
	tolua.cast(faCtrl, 'ui::CCheckBox');
	faCtrl:SetMargin(63, 55, 0, 70);
	faCtrl:SetGravity(ui.LEFT, ui.TOP);
	faCtrl:SetText('{@st42b}Alarm at '..maxSuccessCount..'/'..maxSuccessCount..' or full{/}');
	faCtrl:SetClickSound('button_click_big');
	faCtrl:SetOverSound('button_over');
	faCtrl:SetEventScript(ui.LBUTTONUP, 'FISHALARM_SWITCH', false);
	faCtrl:SetCheck(faSwitchDisabled == true and 0 or 1);

	PctbID = argStr;
	if PctbID == "None" then
		faCtrl:SetVisible(1);
	else
		faCtrl:SetVisible(0);
	end
end


function FISHALARM_CHECK(frame, msg, argStr, argNum)
	_G["FISHING_ITEM_BAG_SET_COUNT_BOX_OLDE"](frame, msg, argStr, argNum);

------------------------------------------------------------------------------
-- Repeat execution of the function (otherwise curSuccessCount stays at 9/10)
------------------------------------------------------------------------------

    local account = session.barrack.GetMyAccount();
    local accountObj = GetMyAccountObj();
    local curSuccessCount = TryGetProp(accountObj, 'FishingSuccessCount');
    local maxSuccessCount = SCR_GET_MAX_FISHING_SUCCESS_COUNT(GetMyPCObject());
    if curSuccessCount == nil then
        return;
    end
    local isMyFishingItemBag = false;
    if argStr ~= nil and argStr ~= 'None' then
        curSuccessCount = argStr;
        isMyFishingItemBag = true;
    end

    local countText = GET_CHILD_RECURSIVELY(frame, 'countText');
    local countBox = countText:GetParent();
    if frame:GetUserValue('OWNER_AID') ~= session.loginInfo.GetAID() and isMyFishingItemBag == false then
        countBox:ShowWindow(0);
        return;
    end
    countText:SetTextByKey('current', curSuccessCount);
    countText:SetTextByKey('max', maxSuccessCount);
    countBox:ShowWindow(1);

------------------------------------------------------------------------------
-- Things addon needs to cure all the diseases
------------------------------------------------------------------------------

    local slotCount = account:GetMaxFishingItemBagSlotCount();
	local itemList = session.GetEtcItemList(IT_FISHING);
	local itemCount = itemList:Count();

------------------------------------------------------------------------------
-- Actual addon part (AKA "stop afking and get back to the game" part)
------------------------------------------------------------------------------

	if (curSuccessCount == maxSuccessCount) and (faSwitchDisabled == false) and (PctbID == "None") then
		FISHALARM_MESSAGE();
		ui.SysMsg("[FishAlarm] Daily limit reached!");
		faSwitchDisabled=true;
		faCtrl:SetCheck(0);
	end
	
	if (itemCount == slotCount) and (curSuccessCount ~= maxSuccessCount) and (faSwitchDisabled == false) and (PctbID == "None") then
		FISHALARM_MESSAGE();
		ui.SysMsg("[FishAlarm] Your Tackle Box is full!");
		faSwitchDisabled=true;
		faCtrl:SetCheck(0);
	end
end


function FISHALARM_SWITCH()
	faSwitchDisabled = faCtrl:IsChecked() ~= 1;
end


function FISHALARM_MESSAGE()
	local frame = ui.GetFrame('indunenter');
	local MATCH_FINDED_SOUND = frame:GetUserConfig('MATCH_FINDED_SOUND');
	imcSound.PlaySoundEvent(MATCH_FINDED_SOUND);
	imcSound.PlaySoundEvent("sys_event_start_1");
    app.SetWindowTopMost();
end


------------------------------------------------------------------------------
-- Addon initiation and hooks
------------------------------------------------------------------------------

function FISHALARM_SETHOOK(newFunct, oldFunct)
    local tempOldFunct = oldFunct .. "_OLDE";
    if _G[tempOldFunct] == nil then
        _G[tempOldFunct] = _G[oldFunct];
        _G[oldFunct] = newFunct;
    else
        _G[oldFunct] = newFunct;
    end
end

function FISHALARM_ON_INIT(addon, frame)
	g.addon = addon;
	g.frame = frame;
	if g.loaded == false then
		FISHALARM_SETHOOK(FISHALARM_UI, "ON_FISHING_ITEM_LIST");
		FISHALARM_SETHOOK(FISHALARM_CHECK, 'FISHING_ITEM_BAG_SET_COUNT_BOX');
		g.loaded = true;
		CHAT_SYSTEM("[FishAlarm] Loaded!");
	end
end
