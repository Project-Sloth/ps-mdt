function UnpackJobData(data) -- QB Style
    local job = {
        name = data.name,
        label = data.label
    }
    local grade = {
        name = data.grade.name,
    }

    return job, grade
end

function PermCheckByJobName(src, jobName)
    local result = true

    if not Config.AllowedJobs[jobName] then
        print(("UserId: %s(%d) tried to access the mdt even though they are not authorised (server direct)"):format(GetPlayerName(src), src))
        result = false
    end

    return result
end

function ProfPic(gender, profilepic)
    if profilepic then return profilepic end
    if gender == "f" then return "img/female.png" end
    return "img/male.png"
end

function IsJobAllowedToMDT(job)
    if Config.PoliceJobs[job] then
        return true
    elseif Config.AmbulanceJobs[job] then
        return true
    elseif Config.DojJobs[job] then
        return true
    else
        return false
    end
end