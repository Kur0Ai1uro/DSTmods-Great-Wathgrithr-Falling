name = "薇格弗德：大荒星陨"
description = "薇格弗德持奔雷矛时，按键朝鼠标落点投出奔雷矛，再俯冲到落点。给饥荒联机用：房主启用后，房间里的人都会加载。技能由服务器结算。"
author = "Kur0Ai1uro"
version = "1.2"
forumthread = ""
api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = true
client_only_mod = false

local KEYS = {
    { description = "R", data = "KEY_R" },
    { description = "F", data = "KEY_F" },
    { description = "G", data = "KEY_G" },
    { description = "Z", data = "KEY_Z" },
    { description = "X", data = "KEY_X" },
    { description = "C", data = "KEY_C" },
    { description = "V", data = "KEY_V" },
    { description = "T", data = "KEY_T" },
    { description = "Q", data = "KEY_Q" },
    { description = "H", data = "KEY_H" },
}

configuration_options = {
    {
        name = "CAST_KEY",
        label = "施放按键",
        hover = "按下时，落点取鼠标所在的地面。",
        options = KEYS,
        default = "KEY_R",
        client = true,
    },
    {
        name = "COOLDOWN",
        label = "冷却（秒）",
        options = {
            { description = "12", data = 12 },
            { description = "20", data = 20 },
            { description = "30", data = 30 },
            { description = "40", data = 40 },
            { description = "60", data = 60 },
        },
        default = 30,
    },
    {
        name = "HUNGER",
        label = "饥饿消耗",
        hover = "薇格弗德的饥饿上限是 120。",
        options = {
            { description = "15", data = 15 },
            { description = "30", data = 30 },
            { description = "45", data = 45 },
            { description = "60", data = 60 },
        },
        default = 30,
    },
    {
        name = "MIN_RANGE",
        label = "最近距离",
        options = {
            { description = "2", data = 2 },
            { description = "3", data = 3 },
            { description = "4", data = 4 },
        },
        default = 3,
    },
    {
        name = "MAX_RANGE",
        label = "最远距离",
        options = {
            { description = "12", data = 12 },
            { description = "18", data = 18 },
            { description = "24", data = 24 },
            { description = "30", data = 30 },
        },
        default = 18,
    },
    {
        name = "USES",
        label = "耐久消耗",
        hover = "整次施放只扣一次，不按命中人数累计。",
        options = {
            { description = "2", data = 2 },
            { description = "4", data = 4 },
            { description = "8", data = 8 },
        },
        default = 4,
    },
}
