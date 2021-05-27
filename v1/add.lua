local base64 = require "ngx.base64"
local crypto = require "common.module.crypto"
local decode_base64url = base64.decode_base64url
local encode_base64url = base64.encode_base64url
local hex2bin = utils.hex2bin
local sub = string.sub
local bin2hex = utils.bin2hex
local gsub = string.gsub
local format = string.format
local len = string.len
local lower = string.lower
local upper = string.upper

local decrypt_v = crypto.decrypt_v
local encrypt_v = crypto.encrypt_v

local _M = {}
_M._VIRSION = "0.0.1"

local mt = {__index = _M}

local function change_flags_to_ids(f)
    if f == "DD" then
        return "1_"
    elseif f == "DT" then
        return "2_"
    elseif f == "JD" then
        return "3_"
    elseif f == "JT" then
        return "4_"
    elseif f == "DF" then
        return "5_"
    else
        return nil
    end
end

local function change_ids_to_flags(id)
    if id == "1_" then
        return "DD"
    elseif id == "2_" then
        return "DT"
    elseif id == "3_" then
        return "JD"
    elseif id == "4_" then
        return "JT"
    elseif id == "5_" then
        return "DF"
    else
        return nil
    end
end

local function data_xor(src, x)
    if not x then
        x = "akx"
    end
    local tmp_src = ""
    local x_len = #x
    for i = 1, #src do
        --print(string.byte(xx,i))
        local tmp1 = bit.bxor(string.byte(src, i), string.byte(x, i % x_len))
        tmp_src = tmp_src .. string.format("%c", tmp1)
    end
    return tmp_src
end

--[[
1111111111111111111111111111111111111111111
yB4fItjbL1U2OxCQMEnn4el3zncbplwrfGUTit3NJDL
结构：
    tt  : 1  - 6
    ot  : 7  - 10
    ptt : 11 - 14
    lid : 15 - 30
    v1  : 31 - 63
1_base64:  63/3*4 + 2 = 86
base64    :最大长度为 30 / 3 * 4 = 40
]]
function _M.build_uuid(v1, lid, ptt, tt, ot)
    --把v1放在最后面
    local def_v1 = "1111111111111111111111111111111111111111111"
    local v1_b = nil
    local flag = nil
    if v1 then
        --必须是xx_开头
        if #v1 > 3 then
            flag = change_flags_to_ids(sub(v1, 1, 2))
            if flag then
                v1_b = decode_base64url(sub(v1, 3, #v1))
            end
        end
    end
    if not flag then
        flag = change_flags_to_ids("DF")
        v1_b = decode_base64url(def_v1)
    end

    local tmp_lid_b = hex2bin(gsub(lid, "-", ""))
    local tmp_ptt_b = hex2bin(format("%08x", ptt))
    --
    local tt_ms = format("%x", tt)
    if #tt_ms % 2 then
        tt_ms = "0" .. tt_ms
    end
    local tmp_tt_b = hex2bin(tt_ms)
    local tmp_ot_b = hex2bin(format("%x", ot))
    local all_data = tmp_tt_b .. tmp_ot_b .. tmp_ptt_b .. tmp_lid_b .. v1_b
    local encrypted_data = encrypt_v(all_data, 255)
    return flag .. encode_base64url(encrypted_data)
end

local function recover_uuid_lid(oid)
    return sub(oid, 1, 8) ..
        "-" ..
            sub(oid, 9, 12) ..
                "-" ..
                    sub(oid, 13, 16) ..
                        "-" .. sub(oid, 17, 20) .. "-" .. sub(oid, 21, 32)
end

--[[
    tt  : 1  - 6
    ot  : 7  - 10
    ptt : 11 - 14
    d78 : 15 - 30
    v1  : 31 - 63
返回值：
    v1,d78,ptt,tt,ot
]]
function _M.parse_uuid(uid)
    --
    local flag = nil
    local uuid_data = {}
    if #uid ~= 89 then
        return nil, "length error"
    end
    local start = 1
    flag = change_ids_to_flags(sub(uid, 1, 2))
    if not flag then
        return nil, "Wrong format"
    end
    start = 3
    --base64解码
    local uid_b_tmp = decode_base64url(sub(uid, start, #uid))
    --解码
    local uid_b = decrypt_v(uid_b_tmp)
    if not uid_b then
        return nil, "decrypt_v failed"
    end

    --数据解析
    start = 1
    local tt_tmp = sub(uid_b, start, start + 5)
    uuid_data["tt"] = tonumber(bin2hex(tt_tmp), 16)
    local ot_tmp = sub(uid_b, start + 6, start + 9)
    uuid_data["ot"] = tonumber(bin2hex(ot_tmp), 16)
    local ptt_tmp = sub(uid_b, start + 10, start + 13)
    uuid_data["ptt"] = tonumber(bin2hex(ptt_tmp), 16)

    local lid_tmp = sub(uid_b, start + 14, start + 29)
    uuid_data["lid"] = recover_uuid_lid(bin2hex(lid_tmp))
    if flag ~= "DF" then
        local v1_tmp = sub(uid_b, start + 30, start + 62)
        uuid_data["v1"] = flag .. encode_base64url(v1_tmp)
    end
    uuid_data["type"] = flag

    return uuid_data, nil
end

--[[
    ptt : 1  -  4
    lid : 5  - 20
    v1  : 21 - 53
]]
function _M.build_sid(v1, lid, ptt)
    local def_v1 = "1111111111111111111111111111111111111111111"
    local v1_b = nil
    local flag = nil
    if v1 then
        --必须是xx_开头
        if #v1 > 3 then
            flag = change_flags_to_ids(sub(v1, 1, 2))
            if flag then
                v1_b = decode_base64url(sub(v1, 3, #v1))
            end
        end
    end
    if not flag then
        flag = change_flags_to_ids("DF")
        v1_b = decode_base64url(def_v1)
    end

    local tmp_lid_b = hex2bin(gsub(lid, "-", ""))
    local tmp_ptt_b = hex2bin(format("%08x", ptt))

    local all_data = tmp_ptt_b .. tmp_lid_b .. v1_b
    local encrypted_data = encrypt_v(all_data, 255)
    return flag .. encode_base64url(encrypted_data)
end

--[[
 53对应76 + 2
    ptt : 1  -  4
    d78 : 5  - 20
    v1  : 21 - 53
    数据格式
    1_base64
    base
返回值：
    v1,d78,ptt,err
]]
function _M.parse_sid(sid)
    local flag = nil
    local sid_data = {}
    if #sid < 72 then
        return sid_data, "length error"
    end
    local start = 1
    flag = change_ids_to_flags(sub(sid, 1, 2))
    if not flag then
        return sid_data, "Wrong format"
    end
    start = 3
    --base64解码
    local uid_b_tmp = decode_base64url(sub(sid, start, #sid))
    --解码
    local uid_b = decrypt_v(uid_b_tmp)
    if not uid_b then
        return sid_data, "decrypt_v failed"
    end
    --数据解析
    start = 1
    local ptt_tmp = sub(uid_b, start, start + 3)
    sid_data["ptt"] = tonumber(bin2hex(ptt_tmp), 16)
    local lid_tmp = sub(uid_b, start + 4, start + 19)
    sid_data["lid"] = recover_uuid_lid(bin2hex(lid_tmp))
    if flag ~= "DF" then
        local v1_tmp = sub(uid_b, start + 20, start + 52)
        sid_data["v1"] = flag .. encode_base64url(v1_tmp)
    end
    sid_data["type"] = flag

    return sid_data, nil
end

function _M.change_ct_binary(ct)
    local timestamp = nil
    local d78 = nil
    local os = nil
    local os_origin = nil
    local err_msg = "ok"
    local binary_data = nil
    repeat
        -- 1. 验证ct
        if "string" ~= type(ct) then
            err_msg = "not string"
            break
        end

        if len(ct) ~= 46 then
            err_msg = "not available dvkey"
            break
        end

        local prefix_ = sub(ct, 1, 2)
        if "CU" ~= prefix_ then
            err_msg = "not available ct"
            break
        end

        -- 2. 解密
        local encrypted_data = decode_base64url(sub(ct, 3))
        if not encrypted_data then
            err_msg = "not available dvkey base64"
            break
        end

        local decrypted_data = decrypt_v(encrypted_data)
        if
            not decrypted_data or len(decrypted_data) > 31 or
                len(decrypted_data) < 16
         then
            err_msg = "not available dvkey decrypt"
            break
        end

        -- 3. tt
        local timestampbin = sub(decrypted_data, 1, 4)
        if not timestampbin then
            err_msg = "get timestamp failed"
            break
        end

        local timestamphex = bin2hex(timestampbin)
        if not timestamphex or #timestamphex == 0 then
            err_msg = "get timestamp failed"
            break
        end
        timestamp = format("%d", "0x" .. timestamphex)

        -- 4. d78
        local d78_bin = sub(decrypted_data, 5, 20)
        if not d78_bin then
            err_msg = "get d78 failed"
            break
        end

        d78 = bin2hex(d78_bin)
        if not d78 or #d78 == 0 then
            err_msg = "get d78 failed"
            break
        end
        local d78_temp_t = {
            sub(d78, 1, 8),
            sub(d78, 9, 12),
            sub(d78, 13, 16),
            sub(d78, 17, 20),
            sub(d78, 21)
        }
        d78 = table.concat(d78_temp_t, "-")

        -- 5. os
        os_origin = bin2hex(sub(decrypted_data, 21, 21))
        os = tonumber(os_origin)
        if not os or os < 0 or os > 1 then
            err_msg = "get os failed"
            break
        end

        if os == 1 then
            d78 = upper(d78)
        else
            d78 = lower(d78)
        end
        binary_data = decrypted_data
    until (true)

    return timestamp, d78, os, binary_data, err_msg
end

return _M
