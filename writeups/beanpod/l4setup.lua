-- vim:set ft=lua:
-- This script shall start mag. For that we need a frame-buffer and io to
-- get access to the required hardware resources. Target platform is ARM
-- Real-View as used with QEmu.
-- name style
--   1.channel (first position is svr)
--     normal server : server_label
--                     e.g. uTsst_system
--                          uTMemory_ns
--     router server : server(router)-router(server)
--                     e.g. router_tee_02
--                          tee_02_router
--   2.flag : is_xxx,"1" true,"0" false
--            e.g. is_tui_feature_supported
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--                        MTK PLATFORM SERVER CONFIG START
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
require("L4");
local l = L4.default_loader;
--##############################################################################
--                                FLAGS
--##############################################################################
--------------------------------------------------------------------------------
--                                ned channels
--------------------------------------------------------------------------------
local ned_cfg = l:new_channel();
local get_version = ned_cfg:svr();
local wait_4_reeagent_channel = l:new_channel();
local wait_4_reeagent = wait_4_reeagent_channel:svr();
--------------------------------------------------------------------------------
--                                get flags
--------------------------------------------------------------------------------
local soter_version = get_version:get_soter_version();
local android_version = get_version:get_android_version();
local is_tui_feature_supported = get_version:module_tui_support();
local is_gp_feature_supported = get_version:module_gp_support();
local is_multi_ta_feature_supported = get_version:multi_ta_support();
local is_debug_test_supported = get_version:debug_test_support();
local is_ese_feature_supported = get_version:module_ese_support();
print(string.format("soter version : 0x%x (0x0:MINI other:NORMAL)", soter_version));
print(string.format("android version : %d (6:M,7:N)", android_version));
print(string.format("soter feature flags : tui 0x%x, gp 0x%x, multi-ta 0x%x, debug 0x%x, ese 0x%x",
is_tui_feature_supported, is_gp_feature_supported, is_multi_ta_feature_supported, is_debug_test_supported, is_ese_feature_supported));
--##############################################################################
--                                CHANNELS
--##############################################################################
--------------------------------------------------------------------------------
--                                sst channels
--------------------------------------------------------------------------------
---- huk&data
local uTsst_system = l:new_channel();
---- huk&data ta
local uTsst_tee_00 = l:new_channel();
local uTsst_tee_01 = l:new_channel();
local uTsst_tee_06 = l:new_channel();
local uTsst_tee_07 = l:new_channel();
local uTsst_tee = l:new_channel();
---- rpmb
local uTsst_l1_system = l:new_channel();
---- rpmb ta
local uTsst_l1_tee_01 = l:new_channel();
local uTsst_l1_gptee0 = l:new_channel();
local uTsst_l1_gptee1 = l:new_channel();
---- rpmb km
local uTsst_l1_tee_km = l:new_channel();
---- rpmb drm
local uTsst_l2_drm_common = l:new_channel();
---- rpmb secmgr
local uTsst_l1_secmgr_ctrl = l:new_channel();
local uTsst_l1_secmgr_bind = l:new_channel();
local uTsst_l1_secmgr_info = l:new_channel();
--------------------------------------------------------------------------------
--                                all type channels
--------------------------------------------------------------------------------
---- utgate
local uTgate_vfs = l:new_channel();
local uTgate_msg = l:new_channel();
local uTgate_reetime = l:new_channel();
---- io
---- service
local uTcapmgr = l:new_channel();
local uTsem = l:new_channel();
local uTMemory = l:new_channel();
local uTMemory_ns = l:new_channel();
local uTSeckey = l:new_channel();
local tester_server = l:new_channel();
local test_namespace = l:new_channel();
local verify_namespace = l:new_channel();
local sec_manager = l:new_channel();
local sec_mgr_produce = l:new_channel();
--------------------------------------------------------------------------------
--                                normal type channels
--------------------------------------------------------------------------------
--if (soter_version ~= 0) then
---------------------------------------
---- ta
local tee_00 = l:new_channel();
local tee_01 = l:new_channel();
local tee = l:new_channel();
local tee_07 = l:new_channel();
local tee_cmd = l:new_channel();
local fingerprint = l:new_channel();
local uTsst_create_partition = l:new_channel();
---- ta/utgate <-> router
local ese_dyn_cap_alloc = l:new_channel();
---- ned send laod finish message
local send_message = uTgate_msg;
---------------------------------------
--end -- end of soter_version ~= 0
--------------------------------------------------------------------------------
--                                BTA loader channels
--------------------------------------------------------------------------------
local utgate_to_bta_loader = l:new_channel();
local vnet_to_bta_loader = l:new_channel();
--------------------------------------------------------------------------------
--                                tui channels
--------------------------------------------------------------------------------
--if (is_tui_feature_supported == 1) then
---------------------------------------
---- utgate/ta -> tui ta
local uTtui_notice = l:new_channel();
local uTtui_display = l:new_channel();
---- tui ta -> input server
local uTinput = l:new_channel();
---- tui ta -> lcd server
local uTdisplay = l:new_channel();
---- tui <-> router
local uTtui_router = l:new_channel();
---------------------------------------
--end -- end of is_tui_feature_supported == 1
--------------------------------------------------------------------------------
--                                drm channels
--------------------------------------------------------------------------------
---- irq
local uTgate_irq = l:new_channel();
---- io
---- drm ta -> uTSeckey service
local uTSeckey_devinf = l:new_channel();
local uTSeckey_crypto = l:new_channel();
--##############################################################################
--                                SERVICES
--##############################################################################
--------------------------------------------------------------------------------
--                                utmemory server
--------------------------------------------------------------------------------
l:start({
    caps= {
        TZ_memory = uTMemory:svr(),
        TZ_memory_ns= uTMemory_ns:svr(),
        sigma0 = L4.cast(L4.Proto.Factory, L4.Env.sigma0):create(L4.Proto.Sigma0),
        test_namespace = test_namespace,
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = {"uTMemory", "Y"},
}, "rom/uTMemory");
--------------------------------------------------------------------------------
--                                utsemaphore server
--------------------------------------------------------------------------------
l:start({
    caps = {
        TZ_sem = uTsem:svr(),
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "uTsem", "Y" },
}, "rom/uTSemaphore");
l:start({
          caps = {
        TZ_capmgr = uTcapmgr:svr(),
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "uTcapmgr", "B" },
}, "rom/uTcapmgr");
--------------------------------------------------------------------------------
--                                utseckey server
--------------------------------------------------------------------------------
l:start({
    caps= {
        TZ_key = uTSeckey:svr(),
        TZ_vfs = uTgate_vfs,
        TZ_sem = uTsem,
        memory_client_ns = uTMemory_ns,
        memory_client = uTMemory,
        ---- drm
        TZ_devinf = uTSeckey_devinf:svr(),
        TZ_crypto = uTSeckey_crypto:svr(),
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = {"uTSeckey", "B"},
}, "rom/uTSeckey");
--------------------------------------------------------------------------------
--                                utgate server
--------------------------------------------------------------------------------
l:start({
    caps = {
        icu = L4.Env.icu,
        ned_goon_signal = wait_4_reeagent_channel,
        memory_client_ns = uTMemory_ns,
        tester_server = tester_server,
        TZ_vfs = uTgate_vfs:svr(),
        TZ_msg = uTgate_msg:svr(),
        TZ_reetime = uTgate_reetime:svr(),
        TZ_key = uTSeckey,
        ---- tui
        TZ_capmgr = uTcapmgr,
        tui_notice_c = uTtui_notice,
        tui_display_c = uTtui_display,
        ---- ta
        fp_server = fingerprint,
        prog01 = tee_00,
        prog02 = tee_01,
        prog06 = tee,
        prog07 = tee_07,
        gp_server = tee_cmd,
        bta_loader = utgate_to_bta_loader,
        ---- drm
        TZ_drm_int = uTgate_irq:svr();
        sst_l1_client = uTsst_l1_gptee0,
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "REEagent", "G" },
},"rom/ree_agent");
------------------------------------------------------------------------
--                                sst server
------------------------------------------------------------------------
wait_4_reeagent:wait_4_reeagent();
print("begin to start sst.");
l:start({
    caps = {
        TZ_vfs = uTgate_vfs,
        TZ_msg = uTgate_msg,
        TZ_key = uTSeckey,
        TZ_sem = uTsem,
        memory_client_ns = uTMemory_ns,
        sst_dyn_creat = uTsst_create_partition:svr(),
        ---- rpmb get random need time cap
        TZ_reetime = uTgate_reetime,
        ---- huk&data
        system = uTsst_system:svr(),
        ---- huk&data ta
        tee_00 = uTsst_tee_00:svr(),
        tee_01 = uTsst_tee_01:svr(),
        tee_06 = uTsst_tee_06:svr(),
        tee_07 = uTsst_tee_07:svr(),
        ---- huk&data gp
        tee = uTsst_tee:svr(),
        ---- huk&data drm
        l2_drm_common = uTsst_l2_drm_common:svr(),
        ---- rpmb
        l1_system = uTsst_l1_system:svr(),
        ---- rpmb ta
        l1_tee_01 = uTsst_l1_tee_01:svr(),
        ---- rpmb km
        l1_tee_km = uTsst_l1_tee_km:svr(),
        ---- rpmb gp
        l1_gptee0 = uTsst_l1_gptee0:svr(),
        l1_gptee1 = uTsst_l1_gptee1:svr(),
        ---- rpmb secmgr
        l1_secmgr_ctrl = uTsst_l1_secmgr_ctrl:svr(),
        l1_secmgr_bind = uTsst_l1_secmgr_bind:svr(),
        l1_secmgr_info = uTsst_l1_secmgr_info:svr(),
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "SST_S", "Y" },
}, "rom/sst-server");
------------------------------------------------------------------------
--                                secure manager server
------------------------------------------------------------------------
wait_4_reeagent:wait_4_reeagent();
print("begin to start secmgr.");
l:start(
    caps = {
        memory_client = uTMemory,
        memory_client_ns = uTMemory_ns,
        TZ_vfs = uTgate_vfs,
        TZ_msg = uTgate_msg,
        TZ_sem = uTsem,
        TZ_key = uTSeckey,
        TZ_reetime = uTgate_reetime,
        TZ_devinf = uTSeckey_devinf,
        TZ_crypto = uTSeckey_crypto,
        test_namespace = test_namespace,
        VSD = verify_namespace:svr(),
        sec_manager = sec_manager:svr(),
        sec_mgr_produce = sec_mgr_produce:svr(),
        sst_client = uTsst_system,
        sst_l1_client = uTsst_l1_secmgr_bind,
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "uTSecManager" },
    l4re_dbg = L4.Dbg.Warn,
}, "rom/uTSecManager", android_version);
------------------------------------------------------------------------
--                              GP Server
------------------------------------------------------------------------
if (is_gp_feature_supported == 1) then
wait_4_reeagent:wait_4_reeagent();
print("begin to start vgptee.");
l:start({
    caps = {
        tee_server_s = tee:svr(),
        tee_server_gp = tee_cmd:svr(),
        memory_client_ns = uTMemory_ns,
        sst_l1_client = uTsst_l1_gptee0,
        sst_client = uTsst_tee,
        TZ_msg = uTgate_msg,
        TZ_vfs = uTgate_vfs,
        TZ_reetime = uTgate_reetime,
        TZ_sem = uTsem,
        TZ_key = uTSeckey,
        VSD = verify_namespace,
        ---- register testcases to uTtester's namespace service.
        test_namespace = test_namespace,
        ---- tui
        tui_notice_c = uTtui_notice,
        tui_display_c = uTtui_display
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "gpserver", "B" },
},"rom/gptee_server");
end -- end of is_gp_feature_supported == 1
------------------------------------------------------------------------
--                                BTA loader
------------------------------------------------------------------------
wait_4_reeagent:wait_4_reeagent();
print("begin to start bta loader.");
l:start(
    caps = {
        -- TODO: for unittest only, should be disabled when unittest is disabled
        test_namespace = test_namespace,
        memory_client = uTMemory,
        memory_client_ns = uTMemory_ns,
        TZ_vfs = uTgate_vfs,
        TZ_msg = uTgate_msg,
        TZ_reetime = uTgate_reetime,
        TZ_capmgr = uTcapmgr,
        TZ_sem = uTsem,
        TZ_key = uTSeckey,
        TZ_devinf = uTSeckey_devinf,
        TZ_crypto = uTSeckey_crypto,
        icu = L4.Env.icu,
        irq_state = uTgate_irq,
        sst_dyn_creat = uTsst_create_partition,
        VSD = verify_namespace,
        sec_manager = sec_manager,
        sec_mgr_produce = sec_mgr_produce,
        fp_server = fingerprint,
        ---- tui
        tui_notice_c = uTtui_notice,
        tui_display_c = uTtui_display,
        -- static SST cap for uTAgent
        sst_l1_system = uTsst_l1_system,
        sst_l2_tee_00 = uTsst_tee_00,
        -- static SST cap for Alipay
        sst_l1_tee_01 = uTsst_l1_tee_01,
        sst_l2_tee_01 = uTsst_tee_01,
        sst_l1_km = uTsst_l1_tee_km,
        sst_l2_km = uTsst_tee_06,
        ese_dyn_cap = ese_dyn_cap_alloc,
        tee_server_s = utgate_to_bta_loader:svr(),
        tee_server = vnet_to_bta_loader:svr(),
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "uTbtaLdr" ,"y"},
    l4re_dbg = L4.Dbg.Warn,
}, "rom/uTbtaLoader");
------------------------------------------------------------------------
--                                unit-test server
------------------------------------------------------------------------
if (is_debug_test_supported == 1) then
wait_4_reeagent:wait_4_reeagent();
print("begin to start tester.");
l:start(
    caps = {
        TZ_msg = uTgate_msg,
        tester_server = tester_server:svr(),
        test_namespace = test_namespace:svr(),
        memory_client_ns= uTMemory_ns,
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "uTtester" },
    l4re_dbg = L4.Dbg.Warn,
}, "rom/uTtester");
end -- end of is_debug_test_supported == 1
------------------------------------------------------------------------
--                                ese server
------------------------------------------------------------------------
if (is_ese_feature_supported == 1) then
wait_4_reeagent:wait_4_reeagent();
print("start ese server signal received\n");
l:start(
    caps = {
        memory_client = uTMemory,
        icu = L4.Env.icu,
        irq_state = uTgate_irq,
        TZ_msg = uTgate_msg,
        memory_client_ns= uTMemory_ns,
        ese_dyn_cap_svr = ese_dyn_cap_alloc:svr(),
    },
    scheduler = L4.Env.user_factory:create(L4.Proto.Scheduler, 0xa0, 0x90),
    log = { "ESE-S", "R" },
}, "rom/ese_server");
end -- end of is_ese_feature_supported == 1
--------------------------------------------------------------------------------
--                                services load finish server
--------------------------------------------------------------------------------
wait_4_reeagent:wait_4_reeagent();
print(string.format("all services load done,send finish message."));
send_message:send_server_finish_to_utgate();
--######################################################################
--                                TAS
--######################################################################
--------------------------------------------------------------------------------
--                                tee load finish server
--------------------------------------------------------------------------------
wait_4_reeagent:wait_4_reeagent();
send_message:send_ta_finish_to_utgate();
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--                        ARM V8 MTK PLAT SERVER CONFIG END
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

