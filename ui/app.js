let canSearchForProfiles = true;
let canSaveProfile = true;
let canRefreshBolo = true;
let canRefreshReports = true;
let canRefreshIncidents = true;
let canSearchForWeapons = true;
let canInputTag = true;
let canInputBoloTag = true;
let canInputBoloOfficerTag = true;
let canSearchReports = true;
let canCreateBulletin = 0;
let mouse_is_inside = false;
let currentTab = ".dashboard-page-container";
let MyName = "";
let canInputReportTag = true;
let canInputReportOfficerTag = true;
let canInputReportCivilianTag = true;
let canSearchForVehicles = true;
let canSearchForReports = true;
let canSaveVehicle = true;
let canSaveWeapon = true;
var LastName = "";
var DispatchNum = 0;
var playerJob = "";
let rosterLink  = "";
let sopLink = "";

//Set this to false if you don't want to show the send to community service button on the incidents page
const canSendToCommunityService = false

let impoundChanged = false;

// TEMP CONFIG OF JOBS
const PoliceJobs = {
  ['police']: true,
  ['lspd']: true,
  ['bcso']: true,
  ['sast']: true,
  ['sasp']: true,
  ['sapr']: true,
  ['doc']: true,
  ['lssd']: true,
}

const AmbulanceJobs = {
  ['ambulance']: true,
}

const DojJobs = {
  ['lawyer']: true,
  ['judge']: true
}

const MONTH_NAMES = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

function getFormattedDate(date, prefomattedDate = false, hideYear = false) {
  const day = date.getDate();
  const month = MONTH_NAMES[date.getMonth()];
  const year = date.getFullYear();
  const hours = date.getHours();
  let minutes = date.getMinutes();

  if (minutes < 10) {
    minutes = `0${minutes}`;
  }

  if (prefomattedDate) {
    return `${prefomattedDate} at ${hours}:${minutes}`;
  }

  if (hideYear) {
    return `${day}. ${month} at ${hours}:${minutes}`;
  }

  return `${day}. ${month} ${year}. at ${hours}:${minutes}`;
}

var quotes = [
  'Project Sloth On Top!',
  'A Discord rewrite fixes everything...',
  'Does anyone even read these?',
  'The best way to predict your future is to create it.',
  'Believe you can and you\'re halfway there.',
  'In three words I can sum up everything I\'ve learned about life: it goes on.',
  'The only way to do great work is to love what you do.',
  'Success is not final, failure is not fatal: it is the courage to continue that counts.',
  'Life is 10% what happens to us and 90% how we react to it.',
  'The only true wisdom is in knowing you know nothing.',
  'If you want to live a happy life, tie it to a goal, not to people or things.',
  'Happiness is not something ready-made. It comes from your own actions.',
  'The greatest glory in living lies not in never falling, but in rising every time we fall.',
  'The only thing necessary for the triumph of evil is for good men to do nothing.',
  'It does not matter how slowly you go as long as you do not stop.',
  'The best time to plant a tree was 20 years ago. The second best time is now.',
  'Believe in yourself and all that you are. Know that there is something inside you that is greater than any obstacle.',
  'Don\'t watch the clock; do what it does. Keep going.',
  'You miss 100% of the shots you don\'t take.',
  'You can\'t go back and change the beginning, but you can start where you are and change the ending.',
  'It\'s not the years in your life that count. It\'s the life in your years.',
  'The greatest glory in living lies not in never falling, but in rising every time we fall.',
  'The two most important days in your life are the day you are born and the day you find out why.',
  'Success is not how high you have climbed, but how you make a positive difference to the world.',
]

function randomizeQuote() {
  return randomQuote = quotes[Math.floor(Math.random() * quotes.length)];
}

function timeAgo(dateParam) {
  if (!dateParam) {
    return null;
  }

  const date =
    typeof dateParam === "object" ? dateParam : new Date(dateParam);
  const DAY_IN_MS = 86400000;
  const today = new Date();
  const yesterday = new Date(today - DAY_IN_MS);
  const seconds = Math.round((today - date) / 1000);
  const minutes = Math.round(seconds / 60);
  const isToday = today.toDateString() === date.toDateString();
  const isYesterday = yesterday.toDateString() === date.toDateString();
  const isThisYear = today.getFullYear() === date.getFullYear();

  if (seconds < 5) {
    return "Just Now";
  } else if (seconds < 60) {
    return `${seconds} Seconds ago`;
  } else if (seconds < 90) {
    return "About a minute ago";
  } else if (minutes < 60) {
    return `${minutes} Minutes ago`;
  } else if (isToday) {
    return getFormattedDate(date, "Today");
  } else if (isYesterday) {
    return getFormattedDate(date, "Yesterday");
  } else if (isThisYear) {
    return getFormattedDate(date, false, true);
  }

  return getFormattedDate(date);
}

function closeContainer(selector) {
  if (
       $(selector).css("display") != "none"
     ) {
       shouldClose = false;
       $(selector).fadeOut(50);
       $(".close-all").css("filter", "none");
     }
}

$(document).ready(() => {
  $(".header").hover(
    function () {
      $(".close-all").css("opacity", "0.5");
    },
    function () {
      $(".close-all").css("opacity", "1");
    }
  );
  $(".incidents-charges-title-container").hover(
    function () {
      $(".incidents-charges-table-container").css("opacity", "0.1");
      $(".close-all").css("filter", "none");
    },
    function () {
      $(".close-all").css("filter", "brightness(30%)");
      $(".incidents-charges-table-container").css("opacity", "1");
    }
  );
  $(".nav-item").click(function () {
    if ($(this).hasClass("active-nav") == false) {
      fidgetSpinner($(this).data("page"));
      currentTab = $(this).data("page");
    }
  });

  $(".profile-items").on("click", ".profile-item", async function () {
    let id = $(this).data("id");
    let profileFingerprint = $(this).data("fingerprint");

    if (profileFingerprint && profileFingerprint !== "") {
      $(".manage-profile-fingerprint-input").val(profileFingerprint);
    } else {
      $(".manage-profile-fingerprint-input").val("");
    }

    let result = await $.post(
      `https://${GetParentResourceName()}/getProfileData`,
      JSON.stringify({
        id: id,
      })
    );

    if (!canInputTag) {
      if ($(".tags-add-btn").hasClass("fa-minus")) {
        $(".tags-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
      $(".tag-input").remove();
      canInputTag = true;
    }

    if ($(".gallery-upload-input").css("display") == "block") {
      $(".gallery-upload-input").slideUp(250);
      setTimeout(() => {
        $(".gallery-upload-input").css("display", "none");
      }, 250);
    }

    if ($(".gallery-add-btn").hasClass("fa-minus")) {
      $(".gallery-add-btn")
        .removeClass("fa-minus")
        .addClass("fa-plus");
    }

    const { vehicles, tags, gallery, convictions, incidents, properties, fingerprint } = result;

    $(".manage-profile-editing-title").html(`You are currently editing ${result["firstname"]} ${result["lastname"]}`);
    $(".manage-profile-citizenid-input").val(result['cid']);
    $(".manage-profile-name-input-1").val(result["firstname"]);
    $(".manage-profile-name-input-2").val(result["lastname"]);
    $(".manage-profile-dob-input").val(result["dob"]);
    $(".manage-profile-phonenumber-input").val(result["phone"]);
    $(".manage-profile-job-input").val(`${result.job}, ${result.grade}`);
    $(".manage-profile-apartment-input").val(`${result.apartment}`);
    $(".manage-profile-url-input").val(result["profilepic"] ?? "");
    $(".manage-profile-info").val(result["mdtinfo"]);
    $(".manage-profile-info").removeAttr("disabled");
    $(".manage-profile-pic").attr("src", result["profilepic"] ?? "img/male.png");
    $(".manage-profile-active-warrant").css("display", "none")
    if (result["warrant"]) {
      $(".manage-profile-active-warrant").css("display", "block");
    }

    $(".licenses-holder").empty();
    $(".tags-holder").empty();
    $(".vehs-holder").empty();
    $(".gallery-inner-container").empty();
    $(".convictions-holder").empty();
    $(".profile-incidents-holder").empty();

    let licencesHTML = '<div style="color: #fff; text-align:center;">No Licenses</div>';
    let tagsHTML = '<div style="color: #fff; text-align:center;">No Tags</div>';
    let convHTML = '<div style="color: #fff; text-align:center;">Clean Record</div>';
    let incidentsHTML = '<div style="color: #fff; text-align:center;">No Incidents</div>';
    let vehHTML = '<div style="color: #fff; text-align:center;">No Vehicles</div>';
    let galleryHTML = '<div style="color: #fff; text-align:center;">No Photos</div>';
    let propertyHTML = '<div style="color: #fff; text-align:center;">No Properties</div>';

    // convert key value pair object of licenses to array
    let licenses = Object.entries(result.licences);

    if (licenses.length == 0 || licenses.length == undefined) {
      var licenseTypes = licenseTypesGlobal;
      licenses = Object.entries(licenseTypes.reduce((licenseType, licenseValue) => (licenseType[licenseValue] = false, licenseType), {}));
    }

    if (licenses.length > 0 && (PoliceJobs[playerJob] !== undefined || DojJobs[playerJob] !== undefined)) {
      licencesHTML = '';
      for (const [lic, hasLic] of licenses) {
        let tagColour = hasLic == true ? "green-tag" : "red-tag";
        licencesHTML += `<span class="license-tag ${tagColour} ${lic}" data-type="${lic}">${titleCase(lic)}</span>`;
      }

      if (vehicles && vehicles.length > 0) {
        vehHTML = '';
        vehicles.forEach(value => {
          vehHTML += `<div class="veh-tag" data-plate="${value.plate}">${value.plate} - ${value.model} </div>`
        })
      }

      if (convictions && convictions.length > 0) {
        convHTML = '';
        convictions.forEach(value => {
          convHTML += `<div class="white-tag">${value} </div>`;
        })
      }

      if (incidents && incidents.length > 0) {
        incidentsHTML='';
        // Sort incidents so most recent appear first
        const sortedIncidents = incidents.sort((a,b) => b.time - a.time);
        sortedIncidents.forEach(value => {
          incidentsHTML += `<div class="white-tag" data-id=${value.id}>
            <div style="display: flex">
              <div class="incident-number">${value.id}</div>
              <div>
                ${value.title}
                <div class="incident-timestamp">${getFormattedDate(new Date(Number(value.time)))}</div>
              </div>
            </div>
          </div>`
        })
      }

      if (properties && properties.length > 0) {
        propertyHTML = '';
        properties.forEach(value => {
          propertyHTML += `<div class="white-tag" data-location="${value.coords}">${value.label} </div>`;
        })
      }
    }

    if (tags && tags.length > 0) {
      tagsHTML = '';
      tags.forEach((tag) => {
        tagsHTML += `<div class="tag">${tag}</div>`;
      })
    }

    if (gallery && gallery.length > 0) {
      galleryHTML = '';
      gallery.forEach(value => {
        galleryHTML += `<img src="${value}" class="gallery-img" onerror="this.src='img/not-found.webp'">`;
      })
    }

    if (result.isLimited) {
      $(".manage-profile-vehs-container").fadeOut(250);
      $(".manage-profile-houses-container").fadeOut(250);
      $(".manage-profile-houses-container").fadeOut(250);
    } else {
      $(".manage-profile-vehs-container").fadeIn(250);
      $(".manage-profile-houses-container").fadeIn(250);
      $(".manage-profile-houses-container").fadeIn(250);
    }

    $(".licenses-holder").html(licencesHTML);
    $(".tags-holder").html(tagsHTML);
    $(".convictions-holder").html(convHTML);
    $(".profile-incidents-holder").html(incidentsHTML);
    $(".vehs-holder").html(vehHTML);
    $(".gallery-inner-container").html(galleryHTML);
    $(".houses-holder").html(propertyHTML);
  });

  $(".bulletin-add-btn").click(function () {
    if (canCreateBulletin == 0) {
      $(this).removeClass("fa-plus").addClass("fa-minus");
      let BulletinId = Number($(".bulletin-item").first().data("id")) + 1;
      if (Number.isNaN(BulletinId)) {
        BulletinId = 1;
      }
      canCreateBulletin = BulletinId;
      $(".bulletin-items-continer")
        .prepend(`<div class="bulletin-item" data-id="${canCreateBulletin}">
                <span contenteditable="true" class="bulletin-item-title"></span>
                <span contenteditable="true" class="bulletin-item-info"></span>
                <div class="bulletin-bottom-info">
                <div class="bulletin-date">${MyName} - Just Now</div>
                </div>
            </div>`);
    } else {
      $(this).removeClass("fa-minus").addClass("fa-plus");
      $(".bulletin-items-continer")
        .find("[data-id='" + canCreateBulletin + "']")
        .remove();
      canCreateBulletin = 0;
    }
  });
  // <div class="bulletin-id">ID: ${canCreateBulletin}</div>
  $(".bulletin-items-continer").on("keydown", ".bulletin-item", function (e) {
    if (e.keyCode === 13) {
      $(".bulletin-add-btn").removeClass("fa-minus").addClass("fa-plus");
      let id = $(this).find(".bulletin-id").text();
      let date = $(this).find(".bulletin-date").text();
      let title = $(this).find(".bulletin-item-title").text();
      let info = $(this).find(".bulletin-item-info").text();
      let time = new Date();
      $.post(
        `https://${GetParentResourceName()}/newBulletin`,
        JSON.stringify({
          title: title,
          info: info,
          time: time.getTime(),
        })
      );
      $(".bulletin-items-continer")
        .find("[data-id='" + canCreateBulletin + "']")
        .remove();
      $(".bulletin-items-continer")
        .prepend(`<div class="bulletin-item" data-id="${canCreateBulletin}">
                <div class="bulletin-item-title">${title}</div>
                <div class="bulletin-item-info">${info}</div>
                <div class="bulletin-bottom-info">

                    <div class="bulletin-date">${MyName} - ${timeAgo(
          Number(time.getTime())
        )}</div>
                </div>
            </div>`);
      canCreateBulletin = 0;
    }
  });
  $(".bulletin-items-continer").on(
    "contextmenu",
    ".bulletin-item",
    function (e) {
      let args = [
        {
          className: "remove-bulletin",
          icon: "fas fa-times",
          text: "Remove Item",
          info: $(this).data("id"),
          status: $(this).data("title"),
        },
      ];
      openContextMenu(e, args);
    }
  );
  $(".contextmenu").on("click", ".remove-bulletin", function () {
    let id = $(this).data("info");
    let title = $(this).data("status")
    $(".bulletin-items-continer")
      .find("[data-id='" + id + "']")
      .remove();
    $.post(
      `https://${GetParentResourceName()}/deleteBulletin`,
      JSON.stringify({
        id: id,
        title: title
      })
    );
    if (canCreateBulletin == id) {
      canCreateBulletin = 0;
    }
    if ($(".bulletin-add-btn").hasClass("fa-minus")) {
      $(".bulletin-add-btn").removeClass("fa-minus").addClass("fa-plus");
    }
  });

  $(".associated-incidents-tags-add-btn").on("click", "", function () {
    document.addEventListener("mouseup", onMouseDownIncidents);
    const source = "associated-incidents-tags";
    $(".incidents-person-search-holder").attr("data-source", source);
    $(".incidents-person-search-container").fadeIn(250); // makes the container visible
    $(".close-all").css("filter", "brightness(15%)");
  });

  $(".convictions-title").on("click", "", function () {
    if ($(".manage-profile-citizenid-input").val()) {
      document.addEventListener("mouseup", onMouseDownIncidents);
      const source = "convictions-title";
      $(".convictions-holder").attr("data-source", source);
      $(".convictions-known-container").fadeIn(250); // makes the container visible
      $(".close-all").css("filter", "brightness(15%)");
    } else {
      $(this).effect("shake", { times: 2, distance: 2 }, 500);
    }
  });

  $(".profile-incidents-title").on("click", "", function () {
    if ($(".manage-profile-citizenid-input").val()) {
      document.addEventListener("mouseup", onMouseDownIncidents);
      const source = "profile-incidents-title";
      $(".profile-incidents-holder").attr("data-source", source);
      $(".incidents-known-container").fadeIn(250); // makes the container visible
      $(".close-all").css("filter", "brightness(15%)");
    } else {
      $(this).effect("shake", { times: 2, distance: 2 }, 500);
    }
  });

  $(".gallery-add-btn").click(function () {
    if ($(".manage-profile-citizenid-input").val()) {
      if ($(".gallery-upload-input").css("display") == "none") {
        $(".gallery-upload-input").slideDown(250);
        $(".gallery-upload-input").css("display", "block");
        $(this).removeClass("fa-plus").addClass("fa-minus");
      } else {
        $(".gallery-upload-input").slideUp(250);
        setTimeout(() => {
          $(".gallery-upload-input").css("display", "none");
        }, 250);
        $(this).removeClass("fa-minus").addClass("fa-plus");
      }
    } else {
      $(this).effect("shake", { times: 2, distance: 2 }, 500);
    }
  });
  $("#gallery-upload-input").keydown(function (e) {
    if (e.keyCode === 13) {
      let URL = $("#gallery-upload-input").val();
      let cid = $(".manage-profile-citizenid-input").val();
      if (URL !== "") {
        let randomNum = Math.ceil(Math.random() * 10).toString();
        $(".gallery-inner-container").prepend(
          `<img src="${URL}" class="gallery-img ${randomNum}" onerror="this.src='img/not-found.webp'">`
        );
        $("#gallery-upload-input").val("");
        $(".gallery-upload-input").slideUp(250);
        setTimeout(() => {
          $(".gallery-upload-input").css("display", "none");
        }, 250);
        $(".gallery-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
    }
  });
  $(".manage-profile-save").click(function () {
    if (canSaveProfile == true) {
      canSaveProfile = false;
      $(".manage-profile-save").empty();
      $(".manage-profile-save").prepend(
        `<span class="fas fa-check"></span>`
      );
      setTimeout(() => {
        $(".manage-profile-save").empty();
        $(".manage-profile-save").html("Save");
        canSaveProfile = true;
      }, 750);

      setTimeout(() => {
        let tags = new Array();
        let gallery = new Array();
        let licenses = {};

        $(".tags-holder")
          .find("span.tag-input, div.tag")
          .each(function () {
          if ($(this).text() != "" && $(this).text() != "No Tags") {
            tags.push($(this).text());
          }
        });

        $(".gallery-inner-container")
        .find("img")
        .each(function () {
          if ($(this).attr("src") != "") {
            gallery.push($(this).attr("src"));
          }
        });

        let pfp = $(".manage-profile-pic").attr("src");
        let newpfp = $(".manage-profile-url-input").val();
        if (newpfp.includes("base64")) {
          newpfp = "img/not-found.webp";
        } else {
          pfp = newpfp;
        }
        let description = $(".manage-profile-info").val();
        let id = $(".manage-profile-citizenid-input").val();

        $(".licenses-holder")
        .find("span")
        .each(function(){
          let type = $(this).data("type")
          if ($(this).attr('class').includes('green-tag')){
            licenses[type] = true;
          }
          else{
            licenses[type] = false;
          }
        })

        const fName = $(".manage-profile-name-input-1").val();
        const sName = $(".manage-profile-name-input-2").val();

        $.post(
          `https://${GetParentResourceName()}/saveProfile`,
          JSON.stringify({
            pfp: pfp,
            description: description,
            id: id,
            fName: fName,
            sName: sName,
            tags: tags,
            gallery: gallery,
            licenses: licenses,
            fingerprint: $(".manage-profile-fingerprint-input").val()
          })
        );
        $(".manage-profile-pic").attr("src", newpfp);
      }, 250);
    }
  });
  $(".manage-incidents-title-holder").on(
    "click",
    ".manage-incidents-save",
    function () {
      if (canSaveProfile == true) {
        canSaveProfile = false;
        $(".manage-incidents-save").empty();
        $(".manage-incidents-save").prepend(
          `<span class="fas fa-check style="margin-top: 3.5px;""></span>`
        );
        setTimeout(() => {
          $(".manage-incidents-save").empty();
          $(".manage-incidents-save").prepend(
            `<span class="fas fa-save" style="margin-top: 3.5px;"></span>`
          );
          canSaveProfile = true;
        }, 750);

        // Title, information, tags, officers involved, civs involved, evidence
        const title = $("#manage-incidents-title-input").val();
        const information = $(".manage-incidents-reports-content").val();
        const dbid = $(".manage-incidents-editing-title").data("id");

        let tags = new Array();
        let officers = new Array();
        let civilians = new Array();
        let evidence = new Array();

        $(".manage-incidents-tags-holder")
          .find("div")
          .each(function () {
            if ($(this).text() != "") {
              tags.push($(this).text());
            }
          });

        $(".manage-incidents-officers-holder")
          .find("div")
          .each(function () {
            if ($(this).text() != "") {
              officers.push($(this).text());
            }
          });

        $(".manage-incidents-civilians-holder")
          .find("div")
          .each(function () {
            if ($(this).text() != "") {
              civilians.push($(this).text());
            }
          });

        $(".manage-incidents-evidence-holder")
          .find("img")
          .each(function () {
            if ($(this).attr("src") != "") {
              evidence.push($(this).attr("src"));
            }
          });

        let time = new Date();

        let associated = new Array();

        $(".associated-incidents-user-container").each(function (
          index
        ) {
          var cid = $(this).data("id");
          var guilty = false;
          var warrant = false;
          var processed = false;
          var isassociated = false;
          var charges = new Array();

          $(".associated-incidents-user-tags-holder")
            .children("div")
            .each(function (index) {
              if ($(this).data("id") == cid) {
                if ($(this).hasClass("green-tag")) {
                  if ($(this).text() == "Guilty") {
                    guilty = true;
                  }
                  if ($(this).text() == "Warrant") {
                    warrant = true;
                  }
                  if ($(this).text() == "Processed") {
                    processed = true;
                  }
                  if ($(this).text() == "Associated") {
                    isassociated = true;
                  }
                }
              }
            });

          $(".associated-incidents-user-holder")
            .children("div")
            .each(function (index) {
              if (
                  ( $(".associated-incidents-user-holder")
                    .children()
                    .eq(index)
                    .data("id") == cid )
              ) {
                charges.push(
                  $(".associated-incidents-user-holder")
                    .children()
                    .eq(index)
                    .html()
                );
              }
            });

          associated.push({
            Cid: $(this).data("id"),
            Warrant: warrant,
            Guilty: guilty,
            Processed: processed,
            Isassociated: isassociated,
            Charges: charges,
            Fine: $(".fine-amount")
              .filter("[data-id='" + $(this).data("id") + "']")
              .val(),
            Sentence: $(".sentence-amount")
              .filter("[data-id='" + $(this).data("id") + "']")
              .val(),
            recfine: $(".fine-recommended-amount")
              .filter("[data-id='" + $(this).data("id") + "']")
              .val(),
            recsentence: $(".sentence-recommended-amount")
              .filter("[data-id='" + $(this).data("id") + "']")
              .val(),
          });
        });

        $.post(
          `https://${GetParentResourceName()}/saveIncident`,
          JSON.stringify({
            ID: dbid,
            title: title,
            information: information,
            tags: tags,
            officers: officers,
            civilians: civilians,
            evidence: evidence,
            associated: associated,
            time: time.getTime(),
          })
        );

        setTimeout(() => {
          if (canRefreshIncidents == true) {
            canRefreshIncidents = false;
            $(".incidents-search-refresh").empty();
            $(".incidents-search-refresh").prepend(
              `<span class="fas fa-spinner fa-spin"></span>`
            );
            setTimeout(() => {
              $(".incidents-search-refresh").empty();
              $(".incidents-search-refresh").html("Refresh");
              canRefreshIncidents = true;
              $.post(
                `https://${GetParentResourceName()}/getAllIncidents`,
                JSON.stringify({})
              );
            }, 1500);
          }
        }, 1000);
      }
    }
  );
  $(".manage-incidents-title-holder").on(
    "click",
    ".manage-incidents-create",
    function () {
      let template = `
      <div style="color: white;">
          <p><strong>📝 Summary:</strong></p>
          <p><em>[Insert Report Summary Here]</em></p>
          <p>&nbsp;</p>
          <p><strong>🧍 Hostage:</strong> [Name Here]</p>
          <p>&nbsp;</p>
          <p><strong>🗄️ Evidence Location:</strong> Stash # | Drawer #</p>
          <p>&nbsp;</p>
          <p><strong>🔪 Weapons/Items Confiscated:</strong></p>
          <p><em>· [Insert List Here]</em></p>
          <p>&nbsp;</p>
          <p>-----</p>
          <p><strong style="background-color: var(--color-1);">💸 Fine:</strong></p>
          <p>&nbsp;</p>
          <p><strong>⌚ Sentence:</strong></p>
          <p>-----</p>
      </div>
  `;
      $("#manage-incidents-title-input").val(
        "Name - Charge - " + $(".date").html()
      );
      $(".manage-incidents-reports-content").trumbowyg({
        changeActiveDropdownIcon: true,
        imageWidthModalEdit: true,
        btns: [
          ['foreColor', 'backColor','fontfamily','fontsize','indent', 'outdent'],
          ['strong', 'em',], ['insertImage'],
          ['viewHTML'],
          ['undo', 'redo'],
          ['formatting'],
          ['superscript', 'subscript'],
          ['link'],
          ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
          ['horizontalRule']
        ],
    });
    $(".manage-incidents-reports-content").trumbowyg('html', template);

      $(".manage-incidents-tags-holder").empty();
      $(".manage-incidents-officers-holder").empty();
      $(".manage-incidents-civilians-holder").empty();
      $(".manage-incidents-evidence-holder").empty();
      $(".manage-incidents-title-holder").empty();
      $(".manage-incidents-title-holder").prepend(
        `
            <div class="manage-incidents-title">Manage Incident</div>
            <div class="manage-incidents-create"> <span class="fas fa-plus" style="margin-top: 3.5px;"></span></div>
            <div class="manage-incidents-save"><span class="fas fa-save" style="margin-top: 3.5px;"></span></div>
            `
      );
      $(".manage-incidents-title").css("width", "66%");
      $(".manage-incidents-create").css("margin-right", "0px");

      $(".incidents-ghost-holder").html("");
      $(".associated-incidents-tags-holder").html("");

      $(".manage-incidents-editing-title").html(
        "You are currently creating a new Incident"
      );
      $(".manage-incidents-editing-title").data("id", 0);

      $(".manage-incidents-tags-add-btn").css("pointer-events", "auto");
      $(".manage-incidents-reports-content").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-officers-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-civilians-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-evidence-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".associated-incidents-tags-add-btn").css(
        "pointer-events",
        "auto"
      );

    }
  );
  $(".tags-add-btn").click(function () {
    if ($(".manage-profile-citizenid-input").val()) {
      if (canInputTag) {
        $(this).removeClass("fa-plus").addClass("fa-minus");
        $(".tags-holder").prepend(
          `<span contenteditable="true" class="tag-input"></span>`
        );
        canInputTag = false;
      } else if (!canInputTag) {
        $(this).removeClass("fa-minus").addClass("fa-plus");
        $(".tag-input").remove();
        canInputTag = true;
      }
    } else {
      $(this).effect("shake", { times: 2, distance: 2 }, 500);
    }
  });

  $(".tags-holder").on("keydown", ".tag-input", function (e) {
    if (e.keyCode === 13) {
      addTag($(".tag-input").text());
      if ($(".tags-add-btn").hasClass("fa-minus")) {
        $(".tags-add-btn").removeClass("fa-minus").addClass("fa-plus");
      }
      $(".tag-input").remove();
    }
  });
  $(".contextmenu").on("click", ".search-vehicle", function () {
    let plate = $(this).data("info");
    fidgetSpinner(".dmv-page-container");
    currentTab = ".dmv-page-container";
    setTimeout(() => {
      $(".dmv-search-input").slideDown(250);
      $(".dmv-search-input").css("display", "block");
      setTimeout(() => {
        $("#dmv-search-input:text").val(plate.toString());
        setTimeout(() => {
          var e = jQuery.Event("keydown");
          e.which = 13; // # Some key code value
          e.keyCode = 13
          $("#dmv-search-input").trigger(e);
        }, 250);
      }, 250);
    }, 250);
  });
  $(".vehs-holder").on("contextmenu", ".veh-tag", function (e) {
    let args = [
      {
        className: "search-vehicle",
        icon: "fas fa-car",
        text: "Search Vehicle",
        info: $(this).data("plate"),
        status: "",
      },
    ];
    openContextMenu(e, args);
  });

  $(".contextmenu").on("click", ".make-waypoint", function () {
    let coord = $(this).data("info").split("===")
    setTimeout(() => {
      $.post(
        `https://${GetParentResourceName()}/SetHouseLocation`,
        JSON.stringify({
          coord: coord,
        })
      );
    }, 250);
  });
  $(".houses-holder").on("contextmenu", ".white-tag", function (e) {
    let args = [
      {
        className: "make-waypoint",
        icon: "fas fa-map-pin",
        text: "Make Waypoint",
        info: $(this).data("location"),
        status: "",
      },
    ];
    openContextMenu(e, args);
  });
  $(".gallery-inner-container").on("click", ".gallery-img", function () {
    if ($(this).css("filter") == "none") {
      $(this).css("filter", "blur(5px)");
    } else {
      $(this).css("filter", "none");
    }
  });
  $(".contextmenu").on("click", ".expand-image", function () {
    expandImage($(this).data("info"));
  });
  $(".contextmenu").on("click", ".remove-image", function () {
    removeImage($(this).data("info"));
  });
  $(".contextmenu").on("click", ".copy-image-link", function () {
    copyImageSource($(this).data("info"));
  });
  $(".contextmenu").on("click", ".remove-image-incident", function () {
    $(".manage-incidents-evidence-holder img")
      .filter("[src='" + $(this).data("info") + "']")
      .remove();
  });
  $(".gallery-inner-container").on(
    "contextmenu",
    ".gallery-img",
    function (e) {
      let args = [
        {
          className: "remove-image",
          icon: "fas fa-times",
          text: "Remove Image",
          info: $(this).attr("src"),
          status: "",
        },
        {
          className: "expand-image",
          icon: "fas fa-expand",
          text: "Expand Image",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
        {
          className: "copy-image-link",
          icon: "fa-regular fa-copy",
          text: "Copy Image Link",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
      ];
      openContextMenu(e, args);
    }
  );

  $(".licenses-holder").on("contextmenu", ".license-tag", function (e) {
    const status = $(this).data("type");
    let type = $(this).html();

    if (type == "Theory") {
      info = "theory";
    } else if (type == "Car") {
      info = "drive";
    } else if (type == "Bike") {
      info = "drive_bike";
    } else if (type == "Truck") {
      info = "drive_truck";
    } else if (type == "Hunting") {
      info = "hunting";
    } else if (type == "Pilot") {
      info = "pilot";
    } else if (type == "Weapon") {
      info = "weapon";
    } else {
      info = type.toLowerCase();
    }

    if ($(this).hasClass("green-tag")) {
      openContextMenu(e, [
        {
          className: "revoke-licence",
          icon: "fas fa-times",
          text: "Revoke License",
          info: info,
          status: status,
        },
      ]);
    } else if ($(this).hasClass("red-tag")) {
      openContextMenu(e, [
        {
          className: "give-licence",
          icon: "fas fa-check",
          text: "Give License",
          info: info,
          status: status,
        },
      ]);
    }
  });

  $(".contextmenu").on("click", ".revoke-licence", function () {
    // $.post(
    //   `https://${GetParentResourceName()}/updateLicence`,
    //   JSON.stringify({
    //     cid: $(".manage-profile-citizenid-input").val(),
    //     type: $(this).data("status"),
    //     status: "revoke",
    //   })
    // );

    const Elem = $(this).data("status");
    $(".license-tag")
      .filter(`[data-type="${Elem}"]`)
      .removeClass("green-tag")
      .addClass("red-tag");

    onMouseDown();
  });

  $(".contextmenu").on("click", ".give-licence", function () {
    // $.post(
    //   `https://${GetParentResourceName()}/updateLicence`,
    //   JSON.stringify({
    //     cid: $(".manage-profile-citizenid-input").val(),
    //     type: $(this).data("status"),
    //     status: "give",
    //   })
    // );

    const Elem = $(this).data("status");
    $(".license-tag")
      .filter(`[data-type="${Elem}"]`)
      .removeClass("red-tag")
      .addClass("green-tag");

    onMouseDown();
  });

  $(".profile-title").click(function () {
    if (canSearchForProfiles == true) {
      if ($(".profile-search-input").css("display") == "none") {
        $(".profile-search-input").slideDown(250);
        $(".profile-search-input").css("display", "block");
      } else {
        $(".profile-search-input").slideUp(250);
        setTimeout(() => {
          $(".profile-search-input").css("display", "none");
        }, 250);
      }
    }
  });

  $("#profile-search-input").keydown(async function (e) {
    if (e.keyCode === 13 && canSearchForProfiles == true) {
      let name = $("#profile-search-input").val();
      if (name != "") {
        canSearchForProfiles = false;
        $(".profile-items").empty();
        $(".profile-items").prepend(
          `<div class="profile-loader"></div>`
        );

        let result = await $.post(
          `https://${GetParentResourceName()}/searchProfiles`,
          JSON.stringify({
            name: name,
          })
        );

        searchProfilesResults(result);
      }
    }
  });

  $(".incidents-title").click(function () {
    if (canSearchForProfiles == true) {
      if ($(".incidents-search-input").css("display") == "none") {
        $(".incidents-search-input").slideDown(250);
        $(".incidents-search-input").css("display", "block");
      } else {
        $(".incidents-search-input").slideUp(250);
        setTimeout(() => {
          $(".incidents-search-input").css("display", "none");
        }, 250);
      }
    }
  });

  $("#incidents-search-input").keydown(function (e) {
    if (e.keyCode === 13 && canSearchForProfiles == true) {
      let incident = $("#incidents-search-input").val();
      if (incident !== "") {
        canSearchForProfiles = false;
        $.post(
          `https://${GetParentResourceName()}/searchIncidents`,
          JSON.stringify({
            incident: incident,
          })
        );
        $(".incidents-items").empty();
        $(".incidents-items").prepend(
          `<div class="profile-loader"></div>`
        );
      }
    }
  });

  function sanitizeInput(input) {
    const map = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#x27;',
      '/': '&#x2F;',
    };
    const reg = /[&<>"'/]/ig;
    return input.replace(reg, (match) => (map[match]));
  }

  $("#dispatchmsg").keydown(function (e) {
    const keyCode = e.which || e.keyCode;
    if (keyCode === 13 && !e.shiftKey) {
      e.preventDefault();
      const time = new Date();
     
      const message = sanitizeInput($(this).val());
      $.post(
        `https://${GetParentResourceName()}/dispatchMessage`,
        JSON.stringify({
          message: message,
          time: time.getTime(),
        })
      );
      $(this).val("");
    }
  });

  $(".incidents-items").on("click", ".incidents-item", function () {
    const id = $(this).data("id");
    $.post(
      `https://${GetParentResourceName()}/getIncidentData`,
      JSON.stringify({
        id: id,
      })
    );
  });
  $(".manage-incidents-civilians-holder").on("click", ".tag", async function () {
      const name = $(this).text();
      fidgetSpinner(".profile-page-container");
      currentTab = ".profile-page-container";
      $(".profile-search-input").slideDown(250);
      $(".profile-search-input").css("display", "block");
      $("#profile-search-input:text").val(name);
      canSearchForProfiles = false;
      let result = await $.post(
        `https://${GetParentResourceName()}/searchProfiles`,
        JSON.stringify({
          name: name,
        })
      );

      searchProfilesResults(result);
    }
  );
  document.onkeyup = function (data) {
    if (data.which == 27) {
      let shouldClose = true;

      if ($(".respond-calls-container").css("display") == "block") {
        shouldClose = false;
        $(".respond-calls-container").fadeOut(500);
        setTimeout(() => {
          $(".close-all").css("filter", "none");
        }, 250);
      }

      if ($(".gallery-image-enlarged").css("display") == "block") {
        shouldClose = false;
        $(".gallery-image-enlarged").fadeOut(150);
        $(".gallery-image-enlarged").css("display", "none");
        $(".close-all").css("filter", "none");
      }

      if ($(".incidents-image-enlarged").css("display") == "block") {
        shouldClose = false;
        $(".incidents-image-enlarged").fadeOut(150);
        $(".incidents-image-enlarged").css("display", "none");
      }

      closeContainer(".incidents-person-search-container");
      closeContainer(".convictions-known-container");
      closeContainer(".incidents-known-container");

      if ($(".incidents-charges-table").css("display") != "none") {
        shouldClose = false;
        $(".incidents-charges-table").slideUp(500);
        $(".incidents-charges-table").fadeOut(500);
        setTimeout(() => {
          $(".close-all").css("filter", "none");
        }, 550);
      }

      if ($(".dispatch-attached-units").css("display") != "none") {
        shouldClose = false;
        $(".dispatch-attached-units").slideUp(500);
        $(".dispatch-attached-units").fadeOut(500);
        setTimeout(() => {
          $(".close-all").css("filter", "none");
        }, 550);
      }

      if ($(".impound-form").css("display") != "none") {
        shouldClose = false;
        $(".impound-form").slideUp(250);
        $(".impound-form").fadeOut(250);
        setTimeout(() => {
          $(".close-all").css("filter", "none");
        }, 550);
      }

      if (shouldClose == true) {
        $.post(`https://${GetParentResourceName()}/escape`, JSON.stringify({}));
      }
    }
  };
  $(".manage-incidents-tags-add-btn").click(function () {
    // if ($(".tag-incident-input")[0]) {
    //   $(this).removeClass("fa-minus").addClass("fa-plus");
    //   $(".tag-incident-input").remove();
    // } else {
    //   $(this).removeClass("fa-plus").addClass("fa-minus");
    //   $(".manage-incidents-tags-holder").prepend(
    //     `<span contenteditable="true" class="tag-incident-input"></span>`
    //   );
    // }
    $(".close-all").css("filter", "none");
    let id = $(".manage-incidents-editing-title").data("id");
    OpenEvidenceLocker(id)
  });

  function OpenEvidenceLocker(id) {
    $.post(`https://${GetParentResourceName()}/OpenEvidenceLocker`, JSON.stringify({
      id,
    }));
  }

  $(".incidents-person-search-name-input").on("keydown", "", function (e) {
    if (e.keyCode === 13) {
      let name = $(".incidents-person-search-name-input").val();
      $.post(
        `https://${GetParentResourceName()}/incidentSearchPerson`,
        JSON.stringify({
          name: name,
        })
      );
    }
  });
  $(".manage-incidents-tags-holder").on(
    "keydown",
    ".tag-incident-input",
    function (e) {
      if (e.keyCode === 13) {
        $(".manage-incidents-tags-holder").prepend(
          `<div class="manage-incidents-tag tag">${$(
            ".tag-incident-input"
          ).text()}</div>`
        );
        // Have it save instantly if it's an existing report.
        if ($(".manage-incidents-tags-add-btn").hasClass("fa-minus")) {
          $(".manage-incidents-tags-add-btn")
            .removeClass("fa-minus")
            .addClass("fa-plus");
        }
        $(".tag-incident-input").remove();
      }
    }
  );

  $(".manage-incidents-officers-add-btn").click(function () {
    const source = "incidents-officers";
    document.addEventListener("mouseup", onMouseDownIncidents);
    $(".incidents-person-search-holder").attr("data-source", source);
    $(".incidents-person-search-container").fadeIn(250); // makes the container visible
    $(".close-all").css("filter", "brightness(15%)");
  });

  $(".manage-incidents-civilians-add-btn").click(function () {
    const source = "incidents-civilians";
    document.addEventListener("mouseup", onMouseDownIncidents);
    $(".incidents-person-search-holder").attr("data-source", source);
    $(".incidents-person-search-container").fadeIn(250); // makes the container visible
    $(".close-all").css("filter", "brightness(15%)");
  });

  $(".manage-incidents-evidence-add-btn").click(function () {
    if ($(".incidents-upload-input").css("display") == "none") {
      $(".incidents-upload-input").slideDown(250);
      $(".incidents-upload-input").css("display", "block");
      $(this).removeClass("fa-plus").addClass("fa-minus");
    } else {
      $(".incidents-upload-input").slideUp(250);
      setTimeout(() => {
        $(".incidents-upload-input").css("display", "none");
      }, 250);
      $(this).removeClass("fa-minus").addClass("fa-plus");
    }
  });

  $("#incidents-upload-input").keydown(function (e) {
    if (e.keyCode === 13) {
      let URL = $("#incidents-upload-input").val();
      let cid = $(".manage-profile-citizenid-input").val();
      if (URL !== "") {
        let randomNum = Math.ceil(Math.random() * 10).toString();
        $(".manage-incidents-evidence-holder").prepend(
          `<img src="${URL}" class="incidents-img ${randomNum}" onerror="this.src='img/not-found.webp'">`
        );
        $("#incidents-upload-input").val("");
        $(".incidents-upload-input").slideUp(250);
        setTimeout(() => {
          $(".incidents-upload-input").css("display", "none");
        }, 250);
        $(".manage-incidents-evidence-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
    }
  });

  $(".manage-incidents-evidence-holder").on(
    "click",
    ".incidents-img",
    function () {
      if ($(this).css("filter") == "none") {
        $(this).css("filter", "blur(5px)");
      } else {
        $(this).css("filter", "none");
      }
    }
  );

  $(".manage-bolos-title-holder").on(
    "click",
    ".manage-bolos-new",
    function () {
      var template = "";
      if ($(".badge-logo").attr("src") == "img/ems_badge.webp") {
        template = `
        <div style="color: white;">
            <p><strong>📝 ICU Room #: [ # ]</strong></p>
            <p><strong>Report ID: [ Report ID ]</strong></p>
            <p><em><br></em></p>
            <p><strong>🧍Time Admitted: [ Date and Time Here ]</strong>&nbsp;</p>
            <p><strong>Surgery: [Yes/No]</strong></p>
            <p><strong>Injuries/Ailments:</strong></p>
            <p><em>· [Enter List Of Injuries Here]</em><br></p>
            <p>&nbsp;</p>
            <p>-----</p>
            <p><strong style="background-color: var(--color-1);">Additional Attending:</strong><br></p>
            <p><em>· [ List Any Other Staff Here ]</em></p>
            <p><strong style="background-color: var(--color-1);">🧑‍🤝‍🧑 Additional Emergency Contacts:</strong><br></p>
            <p><em>· [ Name And Number ]</em></p>
            <p><strong style="background-color: var(--color-1);">Notes:</strong><br></p>
            <p><em>· [Additional Notes Here]</em></p>
            <p>-----</p>
        </div>
    `;
      }
      $(".manage-bolos-editing-title").html(
        "You are currently creating a new BOLO"
      );
      $(".manage-bolos-input-title").val("");
      $(".manage-bolos-input-plate").val("");
      $(".manage-bolos-input-owner").val("");
      $(".manage-bolos-input-individual").val("");
      $(".manage-bolos-reports-content").trumbowyg({
        changeActiveDropdownIcon: true,
        imageWidthModalEdit: true,
        btns: [
          ['foreColor', 'backColor','fontfamily','fontsize','indent', 'outdent'],
          ['strong', 'em',], ['insertImage'],
          ['viewHTML'],
          ['undo', 'redo'],
          ['formatting'],
          ['superscript', 'subscript'],
          ['link'],
          ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
          ['horizontalRule']
        ],
      });
      $(".manage-bolos-reports-content").trumbowyg('html', template);
      $(".manage-bolos-tags-holder").empty();
      $(".bolo-gallery-inner-container").empty();
      $(".manage-officers-tags-holder").empty();

      if ($(".manage-bolos-tags-add-btn").hasClass("fa-minus")) {
        $(".manage-bolos-tags-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
      if ($(".bolo-gallery-add-btn").hasClass("fa-minus")) {
        $(".bolo-gallery-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }

      if ($(".bolo-gallery-upload-input").css("display") == "block") {
        $(".bolo-gallery-upload-input").slideUp(250);
        setTimeout(() => {
          $(".bolo-gallery-upload-input").css("display", "none");
        }, 250);
      }

      canInputTag = true;
      canInputBoloTag = true;
      canInputBoloOfficerTag = true;

      $(".tag-bolo-input").remove();
      canInputBoloTag = true;

      //}
    }
  );

  $(".manage-bolos-title-holder").on(
    "click",
    ".manage-bolos-save",
    function () {
      let existing = !(
        $(".manage-bolos-editing-title").html() ==
        "You are currently creating a new BOLO"
      );
      let id = $(".manage-bolos-editing-title").data("id");
      let title = $("#bolotitle").val();
      let plate = $("#boloplate").val();
      let owner = $("#boloowner").val();
      let individual = $("#boloindividual").val();
      let detail = $("#bolodetail").val();

      let tags = new Array();
      let gallery = new Array();
      let officers = new Array();

      $(".manage-bolos-tags-holder").each(function (index) {
        if ($(this).text() != "") {
          tags.push($(this).text());
        }
      });

      $(".bolo-gallery-inner-container")
      .find("img")
      .each(function () {
        if ($(this).attr("src") != "") {
          gallery.push($(this).attr("src"));
        }
      });

      $(".manage-officers-tags-holder")
      .find("div")
      .each(function () {
        if ($(this).text() != "") {
          officers.push($(this).text());
        }
      });

      let time = new Date();

      $.post(
        `https://${GetParentResourceName()}/newBolo`,
        JSON.stringify({
          existing: existing,
          id: id,
          title: title,
          plate: plate,
          owner: owner,
          individual: individual,
          detail: detail,
          tags: tags,
          gallery: gallery,
          officers: officers,
          time: time.getTime(),
        })
      );
    }
  );

  $(".manage-incidents-evidence-holder").on(
    "contextmenu",
    ".incidents-img",
    function (e) {
      let args = [
        {
          className: "remove-image-incident",
          icon: "fas fa-times",
          text: "Remove Image",
          info: $(this).attr("src"),
          status: "",
        },
        {
          className: "expand-image",
          icon: "fas fa-expand",
          text: "Expand Image",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
        {
          className: "copy-image-link",
          icon: "fa-regular fa-copy",
          text: "Copy Image Link",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
      ];
      openContextMenu(e, args);
    }
  );

  $(".bolos-search-title").click(function () {
    if (canSearchForProfiles == true) {
      if ($(".bolos-search-input").css("display") == "none") {
        $(".bolos-search-input").slideDown(250);
        $(".bolos-search-input").css("display", "block");
      } else {
        $(".bolos-search-input").slideUp(250);
        setTimeout(() => {
          $(".bolos-search-input").css("display", "none");
        }, 250);
      }
    }
  });

  $("#bolos-search-input").keydown(function (e) {
    if (e.keyCode === 13 && canSearchForProfiles == true) {
      let searchVal = $("#bolos-search-input").val();
      if (searchVal !== "") {
        canSearchForProfiles = false;
        $.post(
          `https://${GetParentResourceName()}/searchBolos`,
          JSON.stringify({
            searchVal: searchVal,
          })
        );
        $(".bolos-items").empty();
        $(".bolos-items").prepend(`<div class="profile-loader"></div>`);
      }
    }
  });

  $(".bolos-search-refresh").click(function () {
    if (canRefreshBolo == true) {
      canRefreshBolo = false;
      $(".bolos-search-refresh").empty();
      $(".bolos-search-refresh").prepend(
        `<span class="fas fa-spinner fa-spin"></span>`
      );
      setTimeout(() => {
        $(".bolos-search-refresh").empty();
        $(".bolos-search-refresh").html("Refresh");
        canRefreshBolo = true;
        $.post(`https://${GetParentResourceName()}/getAllBolos`, JSON.stringify({}));
      }, 1500);
    }
  });

  $(".manage-bolos-tags-add-btn").click(function () {
    if (canInputBoloTag) {
      $(this).removeClass("fa-plus").addClass("fa-minus");
      $(".manage-bolos-tags-holder").prepend(
        `<span contenteditable="true" class="tag-bolo-input"></span>`
      );
      canInputBoloTag = false;
    } else if (!canInputBoloTag) {
      $(this).removeClass("fa-minus").addClass("fa-plus");
      $(".tag-bolo-input").remove();
      canInputBoloTag = true;
    }
  });

  $(".manage-bolos-tags-holder").on(
    "keydown",
    ".tag-bolo-input",
    function (e) {
      if (e.keyCode === 13) {
        $(".manage-bolos-tags-holder").prepend(
          `<div class="tag">${$(".tag-bolo-input").text()}</div>`
        );
        // Have it save instantly if it's an existing report.
        if ($(".manage-bolos-tags-add-btn").hasClass("fa-minus")) {
          $(".manage-bolos-tags-add-btn")
            .removeClass("fa-minus")
            .addClass("fa-plus");
        }
        $(".tag-bolo-input").remove();
        canInputBoloTag = true;
      }
    }
  );

  $(".bolo-gallery-add-btn").click(function () {
    //if ($(".manage-profile-citizenid-input").val()) {
    if ($(".bolo-gallery-upload-input").css("display") == "none") {
      $(".bolo-gallery-upload-input").slideDown(250);
      $(".bolo-gallery-upload-input").css("display", "block");
      $(this).removeClass("fa-plus").addClass("fa-minus");
    } else {
      $(".bolo-gallery-upload-input").slideUp(250);
      setTimeout(() => {
        $(".bolo-gallery-upload-input").css("display", "none");
      }, 250);
      $(this).removeClass("fa-minus").addClass("fa-plus");
    }
    //} else {
    // $(this).effect("shake", { times: 2, distance: 2 }, 500)
    // }
  });

  $("#bolo-gallery-upload-input").keydown(function (e) {
    if (e.keyCode === 13) {
      let URL = $("#bolo-gallery-upload-input").val();
      let cid = $(".manage-profile-citizenid-input").val();
      if (URL !== "") {
        let randomNum = Math.ceil(Math.random() * 10).toString();
        $(".bolo-gallery-inner-container").prepend(
          `<img src="${URL}" class="bolo-img ${randomNum}" onerror="this.src='img/not-found.webp'">`
        );
        $("#bolo-gallery-upload-input").val("");
        $(".bolo-gallery-upload-input").slideUp(250);
        setTimeout(() => {
          $(".bolo-gallery-upload-input").css("display", "none");
        }, 250);
        $(".bolo-gallery-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
    }
  });

  $(".bolos-items").on("click", ".bolo-item", function () {
    if ($(".manage-bolos-tags-add-btn").hasClass("fa-minus")) {
      $(".manage-bolos-tags-add-btn")
        .removeClass("fa-minus")
        .addClass("fa-plus");
    }
    if ($(".bolo-gallery-add-btn").hasClass("fa-minus")) {
      $(".bolo-gallery-add-btn")
        .removeClass("fa-minus")
        .addClass("fa-plus");
    }

    if ($(".bolo-gallery-upload-input").css("display") == "block") {
      $(".bolo-gallery-upload-input").slideUp(250);
      setTimeout(() => {
        $(".bolo-gallery-upload-input").css("display", "none");
      }, 250);
    }

    canInputTag = true;
    canInputBoloTag = true;
    canInputBoloOfficerTag = true;
    let id = $(this).data("id");
    $.post(
      `https://${GetParentResourceName()}/getBoloData`,
      JSON.stringify({
        id: id,
      })
    );
  });

  $(".contextmenu").on("click", ".bolo-delete", function () {
    if ($(this).data("info") != 0) {
      if ($(".badge-logo").attr("src") == "img/ems_badge.webp") {
        $(".bolos-items")
          .find("[data-id='" + $(this).data("info") + "']")
          .remove();
        $.post(
          `https://${GetParentResourceName()}/deleteICU`,
          JSON.stringify({
            id: $(this).data("info"),
          })
        );
      }
      $(".bolos-items")
        .find("[data-id='" + $(this).data("info") + "']")
        .remove();
      $.post(
        `https://${GetParentResourceName()}/deleteBolo`,
        JSON.stringify({
          id: $(this).data("info"),
        })
      );
    }
  });

  $(".bolos-items").on("contextmenu", ".bolo-item", function (e) {
    var args = "";
    args = [
      {
        className: "bolo-delete",
        icon: "fas fa-times",
        text: "Delete Bolo",
        info: $(this).data("id"),
        status: "",
      },
    ];
    if ($(".badge-logo").attr("src") == "img/ems_badge.webp") {
      args = [
        {
          className: "bolo-delete",
          icon: "fas fa-times",
          text: "Delete Check-In",
          info: $(this).data("id"),
          status: "",
        },
      ];
    }
    openContextMenu(e, args);
  });
  $(".incidents-ghost-holder").on(
    "contextmenu",
    ".associated-incidents-user-holder",
    function (e) {
      let args = [
        {
          className: "add-charge",
          icon: "fas fa-check",
          text: "Modify Charges",
          info: $(this).data("name"),
          status: "",
        },
      ];
      openContextMenu(e, args);
    }
  );
  $(".contextmenu").on("click", ".add-charge", function () {
    let stupidasscid = $(this).data("info");
    $(".incidents-charges-table").slideDown(500);
    $(".incidents-charges-table").fadeIn(500);
    $("#current-charges-holder").data("cid", $(this).data("info"));
    $("#current-charges-holder").html("");
    $(".associated-incidents-user-holder")
      .children("div")
      .each(function (index) {
        if (
          $(".associated-incidents-user-holder")
            .children()
            .eq(index)
            .data("id") == stupidasscid
        ) {
          const randomNum = Math.ceil(
            Math.random() * 1000
          ).toString();
          $("#current-charges-holder").prepend(
            `<div class="current-charges-tag" data-link="${randomNum}">${$(
              ".associated-incidents-user-holder"
            )
              .children()
              .eq(index)
              .html()}</div>`
          );
        }
      });
    setTimeout(() => {
      $(".close-all").css("filter", "brightness(30%)");
    }, 250);
    $.post(`https://${GetParentResourceName()}/getPenalCode`, JSON.stringify({}));
  });

  var shiftPressed = false;
  $(document).keydown(function (event) {
    shiftPressed = event.keyCode == 16;
  });
  $(document).keyup(function (event) {
    if (event.keyCode == 16) {
      shiftPressed = false;
    }
  });

  $(".offenses-main-container").on("mousedown",".offense-item",function (e) {
      const cid = $("#current-charges-holder").data("cid");
      const newItem = $(this).find(".offense-item-offense").html();
      const Fine = +$(this).data("fine");
      const Sentence = +$(this).data("sentence");
      if (e.which == 1) {
        let randomNum = Math.ceil(Math.random() * 1000).toString();
        $(`[data-name="${cid}"]`).prepend(`<div class="white-tag" data-link="${randomNum}"data-id="${cid}">${$(this).find(".offense-item-offense").html()}</div>`);
        $("#current-charges-holder").prepend(`<div class="current-charges-tag" data-link="${randomNum}">${$(this).find(".offense-item-offense").html()}</div>`);

        const CurrRfine = $(".fine-recommended-amount").filter(`[data-id="${cid}"]`).val();
        const NewFine = +CurrRfine + +Fine;
        $(".fine-recommended-amount").filter(`[data-id="${cid}"]`).val(NewFine);

        const CurrRsentence = $(".sentence-recommended-amount").filter(`[data-id="${cid}"]`).val();
        const NewSentence = +CurrRsentence + +Sentence;
        $(".sentence-recommended-amount").filter(`[data-id="${cid}"]`).val(NewSentence);

      } else if (e.which == 3) {
        $(".associated-incidents-user-holder").children("div").each(function (index) {
          if ($(".associated-incidents-user-holder").children().eq(index).data("id") == cid) {
            if ($(".associated-incidents-user-holder").children().eq(index).html() == newItem) {
              const linkedId = $(".associated-incidents-user-holder").children().eq(index).data("link");
              //$(".current-charges-tag").filter(`[data-link="${linkedId}"]`).remove()
              $(".white-tag").filter(`[data-link="${linkedId}"]`).remove();

              var stop = false;

              $("#current-charges-holder").children("div").each(function (index) {
                if (stop == false) {
                  if ($("#current-charges-holder").children().eq(index).html() == newItem) {
                    const linkedId = $("#current-charges-holder").children().eq(index).data("link");
                    $(".current-charges-tag").filter(`[data-link="${linkedId}"]`).remove();
                    stop = true;
                  }
                }
              });

              const CurrRfine = $(".fine-recommended-amount").filter(`[data-id="${cid}"]`).val();
              const NewFine = +CurrRfine - Fine;
              $(".fine-recommended-amount").filter(`[data-id="${cid}"]`).val(NewFine);

              const CurrRsentence = $(".sentence-recommended-amount").filter(`[data-id="${cid}"]`).val();
              const NewSentence = +CurrRsentence - +Sentence;
              $(".sentence-recommended-amount").filter(`[data-id="${cid}"]`).val(NewSentence);
              return false;
            }
          }
        });
      }
    }
  );

  var timeout;
  $(".offenses-main-container").on("mouseenter",".offense-item",function (e) {
    var descr = $(this).data("descr")
    timeout = setTimeout(function() {
      let args = [
          {
            className: "incidents-remove-tag",
            text: "Remove Tag",
            info: descr,
            status: "",
          },
        ];
      openChargesContextMenu(e, args);
    }, 500);
  });

  $(".offenses-main-container").on("mouseleave",".offense-item",function (e) {
    clearTimeout(timeout)
    hideChargesMenu();
  });

  $(".bolo-gallery-inner-container").on("click", ".bolo-img", function () {
    if ($(this).css("filter") == "none") {
      $(this).css("filter", "blur(5px)");
    } else {
      $(this).css("filter", "none");
    }
  });
  $(".contextmenu").on("click", ".bolo-remove-image", function () {
    $(".bolo-gallery-inner-container img")
      .filter("[src='" + $(this).data("info") + "']")
      .remove();
  });
  $(".bolo-gallery-inner-container").on(
    "contextmenu",
    ".bolo-img",
    function (e) {
      let args = [
        {
          className: "bolo-remove-image",
          icon: "fas fa-times",
          text: "Remove Image",
          info: $(this).attr("src"),
          status: "",
        },
        {
          className: "expand-image",
          icon: "fas fa-expand",
          text: "Expand Image",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
        {
          className: "copy-image-link",
          icon: "fa-regular fa-copy",
          text: "Copy Image Link",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
      ];
      openContextMenu(e, args);
    }
  );

  $(".officers-add-btn").click(function () {
    document.addEventListener("mouseup", onMouseDownIncidents);
    const source = "bolos-officers";
    $(".incidents-person-search-holder").attr("data-source", source);
    $(".incidents-person-search-container").fadeIn(250); // makes the container visible
    $(".close-all").css("filter", "brightness(15%)");
  });

  $(".incidents-ghost-holder").on(
    "click",
    ".associated-incidents-user-tag",
    function () {
      if ($(this).hasClass("red-tag")) {
        $(this).removeClass("red-tag");
        $(this).addClass("green-tag");
        if ($(this).text() == "Associated") {
          $(".associated-incidents-user-holder")
            .filter(`[data-name="${$(this).data("id")}"]`)
            .css("display", "none");
          $(".associated-incidents-fine-input")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .css("display", "none");
          $(".manage-incidents-title-tag")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .css("display", "none");
          $(".associated-incidents-sentence-input")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .css("display", "none");
          $(".associated-incidents-controls")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .css("display", "none");
        }
      } else {
        $(this).removeClass("green-tag");
        $(this).addClass("red-tag");
        if ($(this).text() == "Associated") {
          $(".associated-incidents-user-holder")
            .filter(`[data-name="${$(this).data("id")}"]`)
            .fadeIn(100);
          $(".associated-incidents-fine-input")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .fadeIn(100);
          $(".manage-incidents-title-tag")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .fadeIn(100);
          $(".associated-incidents-sentence-input")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .fadeIn(100);
          $(".associated-incidents-controls")
            .filter(`[data-id="${$(this).data("id")}"]`)
            .fadeIn(100);
        }
      }
    }
  );

  $('.incidents-ghost-holder').on('click', '#jail-button', function() {
    // Get the current sentence and recommended sentence values
    const citizenId = $(this).data("id");
    const sentence = $(".sentence-amount").filter(`[data-id=${citizenId}]`).val();
    const recommendSentence = $(".sentence-recommended-amount").filter(`[data-id=${citizenId}]`).val();
    sendToJail(citizenId, sentence, recommendSentence);
  });

  $('.incidents-ghost-holder').on('click', '#fine-button', function() {
    // Get the current fine and recommended fine values
    const citizenId = $(this).data("id");
    const fine = $(".fine-amount").filter(`[data-id=${citizenId}]`).val();
    const recommendFine = $(".fine-recommended-amount").filter(`[data-id=${citizenId}]`).val();
    const incidentId = $(".manage-incidents-editing-title").data("id");
    sendFine(citizenId, fine, recommendFine, incidentId);
  });

  $('.incidents-ghost-holder').on('click', '#community-service-button', function() {
    // Get the current sentence and recommended sentence values
    const citizenId = $(this).data("id");
    const sentence = $(".sentence-amount").filter(`[data-id=${citizenId}]`).val();
    const recommendSentence = $(".sentence-recommended-amount").filter(`[data-id=${citizenId}]`).val();
    sendToCommunityService(citizenId, sentence, recommendSentence);
  });

  $(".contextmenu").on(
    "click",
    ".associated-incidents-remove-tag",
    function () {
      $(
        `.associated-incidents-tag:contains(${$(this).data("info")})`
      ).remove();
      $(
        `.associated-incidents-user-title:contains(${$(this).data(
          "info"
        )})`
      )
        .parent()
        .remove();
      const incidentId = $(".manage-incidents-editing-title").data("id");
      if (incidentId != 0) {
        $.post(
          `https://${GetParentResourceName()}/removeIncidentCriminal`,
          JSON.stringify({
            cid: $(this).data("status"),
            incidentId: incidentId,
          })
        );
      }
    }
  );
  $(".associated-incidents-tags-holder").on(
    "contextmenu",
    ".associated-incidents-tag",
    function (e) {
      let args = [
        {
          className: "associated-incidents-remove-tag",
          icon: "fas fa-times",
          text: "Remove Tag",
          info: $(this).html(),
          status: $(this).data("id"),
        },
      ];
      openContextMenu(e, args);
    }
  );

  // On click of the search item, it populates the results in the correct area that the search component was triggered from
  $(".incidents-person-search-holder").on(
    "click",
    ".incidents-person-search-item",
    function () {
      $(".incidents-person-search-container").fadeOut(250);
      $(".close-all").css("filter", "none");

      // This is the source element where we triggered the search component to open from
      // It is the area where we want the results to populate when we click on a search result
      const sourceElement = $(".incidents-person-search-holder").data("source");

      // Populate the tags for the given section that corresponds to the sourceElement
      if (sourceElement === "incidents-civilians") {
        $(".manage-incidents-civilians-holder").append(
          `<div class="tag">${$(this).data("name")}</div>`
        );
      } else if (sourceElement === "incidents-officers") {
        $(".manage-incidents-officers-holder").append(
          `<div class="tag">(${$(this).data("callsign")}) ${$(this).data("name")}</div>`
        );
      } else if (sourceElement === "reports-civilians") {
        $(".reports-civilians-tags-holder").append(
          `<div class="tag">${$(this).data("name")}</div>`
        );
      } else if (sourceElement === "reports-officers") {
        $(".reports-officers-tags-holder").append(
          `<div class="tag">(${$(this).data("callsign")}) ${$(this).data("name")}</div>`
        );
      } else if (sourceElement === "bolos-officers") {
        $(".manage-officers-tags-holder").append(
          `<div class="tag">(${$(this).data("callsign")}) ${$(this).data("name")}</div>`
        );
      } else if(sourceElement === "associated-incidents-tags") {
        $(".associated-incidents-tags-holder").prepend(
          `<div class="associated-incidents-tag" data-id="${$(this).data("id")}">${$(this).data("name")}</div>`
        );

        // This section handles populating the fields when you add a new associated user to the incident
        $(".incidents-ghost-holder").prepend(
          `
            <div class="associated-incidents-user-container" data-id="${$(this).data("cid")}">
                <div class="associated-incidents-user-title">${$(this).data("info")}</div>
                <div class="associated-incidents-user-tags-holder">
                    <div class="associated-incidents-user-tag red-tag" data-id="${$(this).data("cid")}">Warrant</div>
                    <div class="associated-incidents-user-tag red-tag" data-id="${$(this).data("cid")}">Guilty</div>
                    <div class="associated-incidents-user-tag red-tag" data-id="${$(this).data("cid")}">Processed</div>
                    <div class="associated-incidents-user-tag red-tag" data-id="${$(this).data("cid")}">Associated</div>
                </div>
                <div class="modify-charges-label"><span class="fas fa-solid fa-info"></span> Right click below to add and/or modify charges.</div>
                <div class="associated-incidents-user-holder" data-name="${$(this).data("cid")}"></div>
                <div class="manage-incidents-title-tag" data-id="${$(this).data("cid")}">Recommended Fine</div>
                <div class="associated-incidents-fine-input" data-id="${$(this).data("cid")}"><img src="img/h7S5f9J.webp"> <input disabled placeholder="0" class="fine-recommended-amount" id="fine-recommended-amount" data-id="${$(this).data("cid")}" type="number"></div>
                <div class="manage-incidents-title-tag" data-id="${$(this).data("cid")}">Recommended Sentence</div>
                <div class="associated-incidents-sentence-input" data-id="${$(this).data("cid")}"><img src="img/9Xn6xXK.webp"> <input disabled placeholder="0" class="sentence-recommended-amount" id="sentence-recommended-amount" data-id="${$(this).data("cid")}" type="number"></div>
                <div class="manage-incidents-title-tag" data-id="${$(this).data("cid")}">Fine</div>
                <div class="associated-incidents-fine-input" data-id="${$(this).data("cid")}"><img src="img/h7S5f9J.webp"> <input placeholder="Enter fine here..." value="0" class="fine-amount" data-id="${$(this).data("cid")}" type="number"></div>
                <div class="manage-incidents-title-tag" data-id="${$(this).data("cid")}">Sentence</div>
                <div class="associated-incidents-sentence-input" data-id="${$(this).data("cid")}"><img src="img/9Xn6xXK.webp"> <input placeholder="Enter months here..." value="0" class="sentence-amount" data-id="${$(this).data("cid")}" type="number"></div>
                <div class="associated-incidents-controls" data-id="${$(this).data("cid")}">
                    <div id="jail-button" class="control-button" data-id="${$(this).data("cid")}"><span class="fa-solid fa-building-columns" style="margin-top: 3.5px;"></span> Jail</div>
                    <div id="fine-button" class="control-button" data-id="${$(this).data("cid")}"><span class="fa-solid fa-file-invoice-dollar" style="margin-top: 3.5px;"></span> Fine</div>
                    ${canSendToCommunityService ? `<div id="community-service-button" class="control-button" data-id="${$(this).data("cid")}"> <span class="fa-solid fa-person-digging" style="margin-top: 3.5px;"></span>Community Service</div>` : ''}
                </div>
            </div>
          `
        );
      }

      // Clear the search results and source
      $(".incidents-person-search-holder").removeData("source"); // Without using this line, we end up reading stale data from the data-source attribute rather than the data-source from the field we clicked on
      $(".incidents-person-search-holder").empty(); // Clear the search results
      $('.incidents-person-search-name-input').val(''); // Reset the search input field
    }
  );

  $(".contextmenu").on("click", ".incidents-remove-tag", function () {
    $(`.tag:contains(${$(this).data("info")})`).remove();
  });

  $(".manage-incidents-tags-holder").on("contextmenu", ".tag", function (e) {
    let args = [
      {
        className: "incidents-remove-tag",
        icon: "fas fa-times",
        text: "Remove Tag",
        info: $(this).html(),
        status: "",
      },
    ];
    openContextMenu(e, args);
  });

  $(".contextmenu").on("click", ".remove-tag", function () {
    $(
      `.tag:contains(${$(this).data("info")})`
    ).remove();
  });

  // Setup the remove tag context menu for each holder section
  const holdersSelectors = [".manage-incidents-civilians-holder", ".manage-incidents-officers-holder", ".reports-civilians-tags-holder", ".reports-officers-tags-holder", ".manage-officers-tags-holder"];
  holdersSelectors.forEach(holder => {
    $(holder).on(
    "contextmenu",
    ".tag",
    function (e) {
      let args = [
        {
          className: "remove-tag",
          icon: "fas fa-times",
          text: "Remove Tag",
          info: $(this).html(),
          status: "",
        },
      ];
      openContextMenu(e, args);
    });
  });

  $(".incidents-search-refresh").click(function () {
    if (canRefreshIncidents == true) {
      canRefreshIncidents = false;
      $(".incidents-search-refresh").empty();
      $(".incidents-search-refresh").prepend(
        `<span class="fas fa-spinner fa-spin"></span>`
      );
      setTimeout(() => {
        $(".incidents-search-refresh").empty();
        $(".incidents-search-refresh").html("Refresh");
        canRefreshIncidents = true;
        $.post(`https://${GetParentResourceName()}/getAllIncidents`, JSON.stringify({}));
      }, 1500);
    }
  });

  $(".contextmenu").on("click", ".incidents-remove-normal-tag", function () {
    $(`.tag:contains(${$(this).data("info")})`).remove();
    let cid = $(".manage-profile-citizenid-input").val();
    if (cid) {
      $.post(
        `https://${GetParentResourceName()}/removeProfileTag`,
        JSON.stringify({
          cid: cid,
          text: $(this).data("info"),
        })
      );
    }
  });
  $(".tags-holder").on("contextmenu", ".tag", function (e) {
    let args = [
      {
        className: "incidents-remove-normal-tag",
        icon: "fas fa-times",
        text: "Remove Tag",
        info: $(this).html(),
        status: "",
      },
    ];
    openContextMenu(e, args);
  });

  $(".reports-search-title").click(function () {
    if (canSearchReports == true) {
      if ($(".reports-search-input").css("display") == "none") {
        $(".reports-search-input").slideDown(250);
        $(".reports-search-input").css("display", "block");
      } else {
        $(".reports-search-input").slideUp(250);
        setTimeout(() => {
          $(".reports-search-input").css("display", "none");
        }, 250);
      }
    }
  });
  $(".incidents-person-search-container").hover(
    function () {
      mouse_is_inside = true;
    },
    function () {
      mouse_is_inside = false;
    }
  );

  $(".convictions-known-container").hover(
    function () {
      mouse_is_inside = true;
    },
    function () {
      mouse_is_inside = false;
    }
  );

  $(".incidents-known-container").hover(
    function () {
      mouse_is_inside = true;
    },
    function () {
      mouse_is_inside = false;
    }
  );

  $(".reports-search-refresh").click(function () {
    if (canRefreshReports == true) {
      canRefreshReports = false;
      $(".reports-search-refresh").empty();
      $(".reports-search-refresh").prepend(
        `<span class="fas fa-spinner fa-spin"></span>`
      );
      setTimeout(() => {
        $(".reports-search-refresh").empty();
        $(".reports-search-refresh").html("Refresh");
        canRefreshReports = true;
        $.post(`https://${GetParentResourceName()}/getAllReports`, JSON.stringify({}));
      }, 1500);
    }
  });

  $(".dispatch-comms-refresh").click(function () {
    $(".dispatch-comms-refresh").empty();
    $(".dispatch-comms-refresh").prepend(
      `<span class="fas fa-spinner fa-spin"></span>`
    );
    setTimeout(() => {
      $(".dispatch-comms-refresh").empty();
      $(".dispatch-comms-refresh").html("Refresh");
      canRefreshReports = true;
      $.post(`https://${GetParentResourceName()}/refreshDispatchMsgs`, JSON.stringify({}));
    }, 1500);
  });

  $(".reports-items").on("click", ".reports-item", function () {
    if (currentTab != ".reports-page-container") {
      fidgetSpinner(".reports-page-container");
      currentTab = ".reports-page-container";
    }

    if ($(".manage-reports-tags-add-btn").hasClass("fa-minus")) {
      $(".manage-reports-tags-add-btn")
        .removeClass("fa-minus")
        .addClass("fa-plus");
    }
    if ($(".reports-gallery-add-btn").hasClass("fa-minus")) {
      $(".reports-gallery-add-btn")
        .removeClass("fa-minus")
        .addClass("fa-plus");
    }

    if ($(".reports-gallery-upload-input").css("display") == "block") {
      $(".reports-gallery-upload-input").slideUp(250);
      setTimeout(() => {
        $(".reports-gallery-upload-input").css("display", "none");
      }, 250);
    }

    canInputTag = true;
    canInputReportTag = true;
    canInputReportOfficerTag = true;
    let id = $(this).data("id");
    $.post(
      `https://${GetParentResourceName()}/getReportData`,
      JSON.stringify({
        id: id,
      })
    );
  });

  $(".manage-reports-tags-add-btn").click(function () {
    if (canInputReportTag) {
      $(this).removeClass("fa-plus").addClass("fa-minus");
      $(".manage-reports-tags-holder").prepend(
        `<span contenteditable="true" class="tag-reports-input"></span>`
      );
      canInputReportTag = false;
    } else if (!canInputReportTag) {
      $(this).removeClass("fa-minus").addClass("fa-plus");
      $(".tag-reports-input").remove();
      canInputReportTag = true;
    }
  });

  $(".manage-reports-tags-holder").on(
    "keydown",
    ".tag-reports-input",
    function (e) {
      if (e.keyCode === 13) {
        $(".manage-reports-tags-holder").prepend(
          `<div class="tag">${$(".tag-reports-input").text()}</div>`
        );
        // Have it save instantly if it's an existing report.
        if ($(".manage-reports-tags-add-btn").hasClass("fa-minus")) {
          $(".manage-reports-tags-add-btn")
            .removeClass("fa-minus")
            .addClass("fa-plus");
        }
        $(".tag-reports-input").remove();
        canInputReportTag = true;
      }
    }
  );

  $(".reports-gallery-add-btn").click(function () {
    //if ($(".manage-profile-citizenid-input").val()) {
    if ($(".reports-gallery-upload-input").css("display") == "none") {
      $(".reports-gallery-upload-input").slideDown(250);
      $(".reports-gallery-upload-input").css("display", "block");
      $(this).removeClass("fa-plus").addClass("fa-minus");
    } else {
      $(".reports-gallery-upload-input").slideUp(250);
      setTimeout(() => {
        $(".reports-gallery-upload-input").css("display", "none");
      }, 250);
      $(this).removeClass("fa-minus").addClass("fa-plus");
    }
    //} else {
    // $(this).effect("shake", { times: 2, distance: 2 }, 500)
    // }
  });

  $("#reports-gallery-upload-input").keydown(function (e) {
    if (e.keyCode === 13) {
      let URL = $("#reports-gallery-upload-input").val();
      let cid = $(".manage-profile-citizenid-input").val();
      if (URL !== "") {
        let randomNum = Math.ceil(Math.random() * 10).toString();
        $(".reports-gallery-inner-container").prepend(
          `<img src="${URL}" class="reports-img ${randomNum}" onerror="this.src='img/not-found.webp'">`
        );
        $("#reports-gallery-upload-input").val("");
        $(".reports-gallery-upload-input").slideUp(250);
        setTimeout(() => {
          $(".reports-gallery-upload-input").css("display", "none");
        }, 250);
        $(".reports-gallery-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
    }
  });

  $(".reports-gallery-inner-container").on(
    "click",
    ".reports-img",
    function () {
      if ($(this).css("filter") == "none") {
        $(this).css("filter", "blur(5px)");
      } else {
        $(this).css("filter", "none");
      }
    }
  );
  $(".contextmenu").on("click", ".reports-remove-image", function () {
    $(".reports-gallery-inner-container img")
      .filter("[src='" + $(this).data("info") + "']")
      .remove();
  });

  $(".reports-gallery-inner-container").on(
    "contextmenu",
    ".reports-img",
    function (e) {
      let args = [
        {
          className: "reports-remove-image",
          icon: "fas fa-times",
          text: "Remove Image",
          info: $(this).attr("src"),
          status: "",
        },
        {
          className: "expand-image",
          icon: "fas fa-expand",
          text: "Expand Image",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
        {
          className: "copy-image-link",
          icon: "fa-regular fa-copy",
          text: "Copy Image Link",
          info: $(this).attr("src"),
          status: $(this).css("filter"),
        },
      ];
      openContextMenu(e, args);
    }
  );

  $(".reports-officers-add-btn").click(function () {
    const source = "reports-officers";
    document.addEventListener("mouseup", onMouseDownIncidents);
    $(".incidents-person-search-holder").attr("data-source", source);
    $(".incidents-person-search-container").fadeIn(250); // makes the container visible
    $(".close-all").css("filter", "brightness(15%)");
  });

  $(".reports-civilians-add-btn").click(function () {
    document.addEventListener("mouseup", onMouseDownIncidents);
    const source = "reports-civilians";
    $(".incidents-person-search-holder").attr("data-source", source);
    $(".incidents-person-search-container").fadeIn(250); // makes the container visible
    $(".close-all").css("filter", "brightness(15%)");
  });

  $(".manage-reports-title-holder").on(
    "click",
    ".manage-reports-new",
    function () {
      let template = "";
      if ($(".badge-logo").attr("src") == "img/ems_badge.webp") {
        template = `
    <div style="color: white;">
        <p><strong>Submitted to ICU?: [Yes/No]</strong></p>
        <p><strong>Incident Report:</strong></p>
        <p><em>· [ Brief summary of what happened and who did what while on scene. Note anything that stood out about the scene as well as what was done to treat the patient ]</em></p>
        <p><strong>List of Injuries:</strong></p>
        <p><em>· [ State what injury or injuries occurred ]</em></p>
        <p><strong>Surgical Report:</strong></p>
        <p><em>· [ Full report on what was done in surgery, list any complications or anything that was found while in operation. Note who was attending and what they did during the surgery. At the end of the report be sure to note the state of the patient after ]</em></p>
        <p>-----</p>
        <p><strong>Attending:</strong></p>
        <p><em>· [ List Any Attending Here ]</em></p>
        <p><strong>Medications Applied:</strong></p>
        <p><em>· [ List Any Attending Here ]</em></p>
        <p>-----</p>
        <br>
        <p><strong>Notes:</strong></p>
        <p><em>[ Additional Notes Here ]</em></p>
    </div>
`;}
      $(".manage-reports-editing-title").html(
        "You are currently creating a new report"
      );
      $(".manage-reports-input-title").val("");
      $(".manage-reports-input-type").val("");
      $(".manage-reports-reports-content").trumbowyg({
        changeActiveDropdownIcon: true,
        imageWidthModalEdit: true,
        btns: [
          ['foreColor', 'backColor','fontfamily','fontsize','indent', 'outdent'],
          ['strong', 'em',], ['insertImage'],
          ['viewHTML'],
          ['undo', 'redo'],
          ['formatting'],
          ['superscript', 'subscript'],
          ['link'],
          ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
          ['horizontalRule']
        ],
      });
      $(".manage-reports-reports-content").trumbowyg('html', template);
      $(".manage-reports-tags-holder").empty();
      $(".reports-gallery-inner-container").empty();
      $(".reports-officers-tags-holder").empty();
      $(".reports-civilians-tags-holder").empty();

      if ($(".manage-reports-tags-add-btn").hasClass("fa-minus")) {
        $(".manage-reports-tags-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }
      if ($(".reports-gallery-add-btn").hasClass("fa-minus")) {
        $(".reports-gallery-add-btn")
          .removeClass("fa-minus")
          .addClass("fa-plus");
      }

      if ($(".reports-gallery-upload-input").css("display") == "block") {
        $(".reports-gallery-upload-input").slideUp(250);
        setTimeout(() => {
          $(".reports-gallery-upload-input").css("display", "none");
        }, 250);
      }

      canInputTag = true;
      canInputReportTag = true;
      canInputReportOfficerTag = true;

      $(".tag-reports-input").remove();
      canInputReportTag = true;

      //}
    }
  );

  $("#reports-search-input").keydown(function (e) {
    if (e.keyCode === 13 && canSearchForReports == true) {
      let name = $(this).val();
      if (name !== "") {
        canSearchForReports = false;
        $.post(
          `https://${GetParentResourceName()}/searchReports`,
          JSON.stringify({
            name: name,
          })
        );
        $(".reports-items").empty();
        $(".reports-items").prepend(
          `<div class="profile-loader"></div>`
        );
      }
    }
  });

  $(".manage-reports-title-holder").on(
    "click",
    ".manage-reports-save",
    function () {
      let existing = !(
        $(".manage-reports-editing-title").html() ==
        "You are currently creating a new report"
      );
      let id = $(".manage-reports-editing-title").data("id");
      let title = $("#reporttitle").val();
      let type = $("#reporttype").val();
      let details = $("#reportdetail").val();
      let tags = new Array();
      let gallery = new Array();
      let officers = new Array();
      let civilians = new Array();

      $(".manage-reports-tags-holder")
        .find("div")
        .each(function () {
          if ($(this).text() != "") {
            tags.push($(this).text());
          }
        });

      $(".reports-gallery-inner-container")
        .find("img")
        .each(function () {
          if ($(this).attr("src") != "") {
            gallery.push($(this).attr("src"));
          }
        });

      $(".reports-officers-tags-holder")
        .find("div")
        .each(function () {
          if ($(this).text() != "") {
            officers.push($(this).text());
          }
        });

      $(".reports-civilians-tags-holder")
      .find("div")
      .each(function () {
        if ($(this).text() != "") {
          civilians.push($(this).text());
        }
      });

      let time = new Date();

      $.post(
        `https://${GetParentResourceName()}/newReport`,
        JSON.stringify({
          existing: existing,
          id: id,
          title: title,
          type: type,
          details: details,
          tags: tags,
          gallery: gallery,
          officers: officers,
          civilians: civilians,
          time: time.getTime(),
        })
      );
    }
  );

  $(".dmv-search-title").click(function () {
    if (canSearchForVehicles == true) {
      if ($(".dmv-search-input").css("display") == "none") {
        $(".dmv-search-input").slideDown(250);
        $(".dmv-search-input").css("display", "block");
      } else {
        $(".dmv-search-input").slideUp(250);
        setTimeout(() => {
          $(".dmv-search-input").css("display", "none");
        }, 250);
      }
    }
  });

  $("#dmv-search-input").keydown(async function (e) {
    if (e.keyCode === 13 && canSearchForVehicles == true) {
      let name = $("#dmv-search-input").val();
      if (name !== "") {
        canSearchForVehicles = false;
        $(".dmv-items").empty();
        $(".dmv-items").prepend(`<div class="profile-loader"></div>`);

        let result = await $.post(
          `https://${GetParentResourceName()}/searchVehicles`,
          JSON.stringify({
            name: name,
          })
        );
        if (result.length === 0) {
          $(".dmv-items").html(
            `
                            <div class="profile-item" data-id="0">

                                <div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 5px; width: 100%; padding: 5px;">
                                <div style="display: flex; flex-direction: column;">
                                    <div class="profile-item-title">No Vehicles Matching that search</div>
                                    </div>
                                    <div class="profile-bottom-info">
                                    </div>
                                </div>
                            </div>
                    `
          );
          canSearchForVehicles = true;
          return true;
        }
        $(".dmv-items").empty();

        let vehicleHTML = "";

        result.forEach((value) => {
          let paint = value.color;
          let impound = "red-tag";
          let bolo = "red-tag";
          let codefive = "red-tag";
          let stolen = "red-tag";

          if (value.state == 'Impounded') {
            impound = "green-tag";
          }

          if (value.bolo) {
            bolo = "green-tag";
          }

          if (value.code) {
            codefive = "green-tag";
          }

          if (value.stolen) {
            stolen = "green-tag";
          }

          vehicleHTML += `
                        <div class="dmv-item" data-id="${value.id}" data-dbid="${value.dbid}" data-plate="${value.plate}">
                            <img src="${value.image}" class="dmv-image">
                            <div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 5px; width: 100%; padding: 5px;">
                            <div style="display: flex; flex-direction: column;">
                                <div class="dmv-item-title">${value.model}</div>
                                    <div class="dmv-tags">
                                        <div class="dmv-tag ${paint}-color">${value.colorName}</div>
                                        <div class="dmv-tag ${impound}">Impound</div>
                                        <div class="dmv-tag ${bolo}">BOLO</div>
                                        <div class="dmv-tag ${stolen}">Stolen</div>
                                        <div class="dmv-tag ${codefive}">Code 5</div>
                                    </div>
                                </div>
                                <div class="dmv-bottom-info">
                                    <div class="dmv-id">Plate: ${value.plate} · Owner: ${value.owner}</div>
                                </div>
                            </div>
                        </div>
                    `;
        });

        $(".dmv-items").html(vehicleHTML);

        canSearchForVehicles = true;

      }
    }
  });

  $(".dmv-items").on("click", ".dmv-item", function () {
    $.post(
      `https://${GetParentResourceName()}/getVehicleData`,
      JSON.stringify({
        plate: $(this).data("plate"),
      })
    );
  });

  $(".vehicle-information-title-holder").on(
    "click",
    ".vehicle-information-save",
    function () {
      if (canSaveVehicle) {
        canSaveVehicle = false;
        $(".vehicle-information-save").empty();
        $(".vehicle-information-save").prepend(
          `<span class="fas fa-check"></span>`
        );
        setTimeout(() => {
          $(".vehicle-information-save").empty();
          $(".vehicle-information-save").html("Save");
          canSaveVehicle = true;
        }, 750);
        setTimeout(() => {
          let dbid = $(".vehicle-information-title-holder").data("dbid");
          let plate = $(".vehicle-info-plate-input").val();
          let notes = $(".vehicle-info-content").val();
          let points = $("#vehiclePointsSlider").val();

          let imageurl = $(".vehicle-info-image").attr("src");
          let newImageurl = $(".vehicle-info-imageurl-input").val();
          if (newImageurl.includes("base64")) {
            imageurl = "img/not-found.webp";
          } else {
            imageurl = newImageurl;
          }

          let code5 = false;
          let code5tag = $(".vehicle-tags").find(".code5-tag");
          if (code5tag.hasClass("green-tag")) {
            code5 = true
          }

          let stolen = false;
          let stolentag = $(".vehicle-tags").find(".stolen-tag");
          if (stolentag.hasClass("green-tag")) {
            stolen = true
          }

          let impoundInfo = {}
          impoundInfo.impoundActive = $(".vehicle-tags").find(".impound-tag").hasClass("green-tag")
          impoundInfo.impoundChanged = impoundChanged
          if (impoundChanged === true) {
            if (impoundInfo.impoundActive === true) {
              impoundInfo.plate = $(".impound-plate").val();
              impoundInfo.linkedreport = $(".impound-linkedreport").val();
              impoundInfo.fee = $(".impound-fee").val();
              impoundInfo.time = $(".impound-time").val();
            }
          }

          $.post(
            `https://${GetParentResourceName()}/saveVehicleInfo`,
            JSON.stringify({
              dbid: dbid,
              plate: plate,
              imageurl: imageurl,
              notes: notes,
              stolen: stolen,
              code5: code5,
              impound: impoundInfo,
              points: points,
            })
          );

          impoundChanged = false;
          $(".vehicle-info-image").attr("src", newImageurl);
        }, 250);
      }
    }
  );

  $(".contextmenu").on("click", ".mark-code-5", function () {
    let tag = $(".vehicle-tags").find(".code5-tag");
    if (tag.hasClass("red-tag")) {
      tag.removeClass("red-tag").addClass("green-tag");
    }
  });

  $(".contextmenu").on("click", ".remove-code-5", function () {
    let tag = $(".vehicle-tags").find(".code5-tag");
    if (tag.hasClass("green-tag")) {
      tag.removeClass("green-tag").addClass("red-tag");
    }
  });

  $(".vehicle-tags").on("contextmenu", ".code5-tag", function (e) {
    let plate = $(".vehicle-info-plate-input").val();
    if (plate) {
      let args = [];
      if ($(this).hasClass("red-tag")) {
        args = [
          {
            className: "mark-code-5",
            icon: "fas fa-check",
            text: "Mark as Code 5",
            info: plate,
            status: "",
          },
        ];
      } else {
        args = [
          {
            className: "remove-code-5",
            icon: "fas fa-times",
            text: "Remove Code 5 Status",
            info: plate,
            status: "",
          },
        ];
      }

      openContextMenu(e, args);
    }
  });

  $(".contextmenu").on("click", ".mark-stolen", function () {
    let tag = $(".vehicle-tags").find(".stolen-tag");
    if (tag.hasClass("red-tag")) {
      tag.removeClass("red-tag").addClass("green-tag");
    }
  });

  $(".contextmenu").on("click", ".remove-stolen", function () {
    let tag = $(".vehicle-tags").find(".stolen-tag");
    if (tag.hasClass("green-tag")) {
      tag.removeClass("green-tag").addClass("red-tag");
    }
  });

  $(".vehicle-tags").on("contextmenu", ".stolen-tag", function (e) {
    let plate = $(".vehicle-info-plate-input").val();
    if (plate) {
      let args = [];
      if ($(this).hasClass("red-tag")) {
        args = [
          {
            className: "mark-stolen",
            icon: "fas fa-check",
            text: "Mark as Stolen",
            info: plate,
            status: "",
          },
        ];
      } else {
        args = [
          {
            className: "remove-stolen",
            icon: "fas fa-times",
            text: "Remove Code 5 Status",
            info: plate,
            status: "",
          },
        ];
      }

      openContextMenu(e, args);
    }
  });

  $(".contextmenu").on("click", ".impound-vehicle", function () {
    const plate = $(this).data("info");
    $(".impound-linkedreport").val("").removeAttr("disabled");
    $(".impound-fee").val("").removeAttr("disabled");
    $(".impound-time").val("").removeAttr("disabled");
    $(".impound-fee").css("color", "white");
    $(".impound-cancel").html("Cancel");
    $(".impound-submit").fadeIn(250);
    $(".impound-form").slideDown(250);
    $(".impound-form").fadeIn(250);
    $(".impound-form").data("plate", plate);
    $(".impound-plate").val(plate);
  });

  $(".impound-submit").click(function () {
    const plate = $(".impound-plate").val();
    const linkedreport = $(".impound-linkedreport").val();
    const fee = $(".impound-fee").val();
    const time = $(".impound-time").val();

    if (!plate || plate === "") {
      $(".impound-form").css("border", "1px solid rgb(184, 3, 3)");
      setTimeout(() => {
        $(".impound-form").css(
          "border",
          "1px solid rgb(168, 168, 168)"
        );
      }, 500);
      return;
    }

    if (!linkedreport || linkedreport === "") {
      $(".impound-form").css("border", "1px solid rgb(184, 3, 3)");
      setTimeout(() => {
        $(".impound-form").css(
          "border",
          "1px solid rgb(168, 168, 168)"
        );
      }, 500);
      return;
    }

    if (!fee || fee === "") {
      $(".impound-form").css("border", "1px solid rgb(184, 3, 3)");
      setTimeout(() => {
        $(".impound-form").css(
          "border",
          "1px solid rgb(168, 168, 168)"
        );
      }, 500);
      return;
    }

    if (!time || time === "") {
      $(".impound-form").css("border", "1px solid rgb(184, 3, 3)");
      setTimeout(() => {
        $(".impound-form").css(
          "border",
          "1px solid rgb(168, 168, 168)"
        );
      }, 500);
      return;
    }

    /* $.post(
      `https://${GetParentResourceName()}/impoundVehicle`,
      JSON.stringify({
        plate: plate,
        linkedreport: linkedreport,
        fee: fee,
        time: time,
      })
    ); */

    //$(".impound-plate").val("");
    //$(".impound-linkedreport").val("");
    //$(".impound-fee").val("");
    //$(".impound-time").val("");
    //$(".impound-fee").css("color", "white");

    $(".vehicle-tags").find(".impound-tag").addClass("green-tag").removeClass("red-tag");

    $(".impound-form").slideUp(250);
    $(".impound-form").fadeOut(250);
    impoundChanged = true;
  });

  $(".impound-cancel").click(function () {
    $(".impound-form").slideUp(250);
    $(".impound-form").fadeOut(250);

    $(".impound-plate").val("");
    $(".impound-linkedreport").val("");
    $(".impound-fee").val("");
    $(".impound-time").val("");
    $(".impound-fee").css("color", "white");
  });

  $(".contextmenu").on("click", ".remove-impound", function () {
    const plate = $(this).data("info");
    /* $.post(
      `https://${GetParentResourceName()}/removeImpound`,
      JSON.stringify({
        plate: plate,
      })
    ); */
    $(".impound-plate").val("");
    $(".impound-linkedreport").val("");
    $(".impound-fee").val("");
    $(".impound-time").val("");
    impoundChanged = true;

    $(".vehicle-tags")
      .find(".impound-tag")
      .addClass("red-tag")
      .removeClass("green-tag");
  });

  $(".contextmenu").on("click", ".status-impound", function () {
    const plate = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/statusImpound`,
      JSON.stringify({
        plate: plate,
      })
    );
  });

  $(".vehicle-tags").on("contextmenu", ".impound-tag", function (e) {
    let plate = $(".vehicle-info-plate-input").val();
    if (plate) {
      let args = [];
      if ($(this).hasClass("red-tag")) {
        args = [
          {
            className: "impound-vehicle",
            icon: "fas fa-check",
            text: "State Impound",
            info: plate,
            status: "",
          },
        ];
      } else {
        args = [
          {
            className: "remove-impound",
            icon: "fas fa-times",
            text: "Unimpound Vehicle",
            info: plate,
            status: "",
          },
          {
            className: "status-impound",
            icon: "fas fa-info-circle",
            text: "View Impound Status",
            info: plate,
            status: "",
          },
        ];
      }
      openContextMenu(e, args);
    }
  });


  $(".calls-search-title").click(function () {
    if (canSearchForProfiles == true) {
      if ($(".calls-search-input").css("display") == "none") {
        $(".calls-search-input").slideDown(250);
        $(".calls-search-input").css("display", "block");
      } else {
        $(".calls-search-input").slideUp(250);
        setTimeout(() => {
          $(".calls-search-input").css("display", "none");
        }, 250);
      }
    }
  });

  $("#calls-search-input").keydown(function (e) {
    if (e.keyCode === 13) {
      let searchCall = $("#calls-search-input").val();
      if (searchCall !== "") {
        $.post(
          `https://${GetParentResourceName()}/searchCalls`,
          JSON.stringify({
            searchCall: searchCall,
          })
        );
        $(".calls-items").empty();
        $(".calls-items").prepend(`<div class="profile-loader"></div>`);
      }
    }
  });

  $(".weapons-search-title").click(function () {
    if (canSearchForWeapons == true) {
      if ($(".weapons-search-input").css("display") == "none") {
        $(".weapons-search-input").slideDown(250);
        $(".weapons-search-input").css("display", "block");
      } else {
        $(".weapons-search-input").slideUp(250);
        setTimeout(() => {
          $(".weapons-search-input").css("display", "none");
        }, 250);
      }
    }
  });

  $("#weapons-search-input").keydown(async function (e) {
    if (e.keyCode === 13 && canSearchForWeapons == true) {
      let name = $("#weapons-search-input").val();
      if (name !== "") {
        canSearchForWeapons = false;
        $(".weapons-items").empty();
        $(".weapons-items").prepend(`<div class="profile-loader"></div>`);

        let result = await $.post(
          `https://${GetParentResourceName()}/searchWeapons`,
          JSON.stringify({
            name: name,
          })
        );
        if (result.length === 0) {
          $(".weapons-items").html(
            `
                            <div class="profile-item" data-id="0">

                                <div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 5px; width: 100%; padding: 5px;">
                                <div style="display: flex; flex-direction: column;">
                                    <div class="profile-item-title">No Weapons Matching that search</div>
                                    </div>
                                    <div class="profile-bottom-info">
                                    </div>
                                </div>
                            </div>
                    `
          );
          canSearchForWeapons = true;
          return true;
        }
        $(".weapons-items").empty();

        let weaponHTML = "";

        result.forEach((value) => {
          weaponHTML += `
                        <div class="weapons-item" data-id="${value.id}" data-dbid="${value.id}" data-serial="${value.serial}">
                            <img src="${value.image}" class="weapons-image">
                            <div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 5px; width: 100%; padding: 5px;">
                              <div style="display: flex; flex-direction: column;">
                                <div class="weapons-item-title">${value.weapModel} - Class ${value.weapClass}</div>

                                </div>
                                <div class="weapons-bottom-info">
                                  <div class="weapons-id">Serial Number: ${value.serial} · Owner: ${value.owner} · ID: ${value.id}</div>
                                </div>
                            </div>
                        </div>
                    `;
        });

        $(".weapons-items").html(weaponHTML);

        canSearchForWeapons = true;
      }
    }
  });

  $(".weapon-information-title-holder").on("click", ".weapon-information-new", function () {
    $(".weapon-information-title-holder").data("dbid", 0);
    $(".weapon-info-serial-input").val("");
    $(".weapon-info-owner-input").val("");
    $(".weapon-info-class-input").val("");
    $(".weapon-info-model-input").val("");
    $(".weapon-info-imageurl-input").val("img/not-found.webp");

    canSaveWeapon = true;
  }
);

  $(".weapon-information-title-holder").on("click", ".weapon-information-save", function () {
    if (canSaveProfile == true) {
      canSaveProfile = false;
        $(".manage-profile-save").empty();
        $(".manage-profile-save").prepend(
          `<span class="fas fa-check"></span>`
        );
        setTimeout(() => {
          $(".manage-profile-save").empty();
          $(".manage-profile-save").html("Save");
          canSaveProfile = true;
        }, 750);

        setTimeout(() => {
          let serial = $(".weapon-info-serial-input").val();
          let notes = $(".weapon-info-content").val();
          let owner = $(".weapon-info-owner-input").val();
          let weapClass = $(".weapon-info-class-input").val();
          let weapModel = $(".weapon-info-model-input").val();

          let imageurl = $(".weapon-info-image").attr("src");
          let newImageurl = $(".weapon-info-imageurl-input").val();
          if (newImageurl.includes("base64")) {
            imageurl = "img/not-found.webp";
          } else {
            imageurl = newImageurl;
          }

          $.post(
            `https://${GetParentResourceName()}/saveWeaponInfo`,
            JSON.stringify({
              serial: serial,
              imageurl: imageurl,
              notes: notes,
              owner: owner,
              weapClass: weapClass,
              weapModel: weapModel,
            })
          );

          $(".weapon-info-image").attr("src", newImageurl);
        }, 250);
    }
  }
);

  $(".weapons-items").on("click", ".weapons-item", function () {
    $.post(
      `https://${GetParentResourceName()}/getWeaponData`,
      JSON.stringify({
        serial: $(this).data("serial"),
      })
    );
  });

  $(".contextmenu").on("click", ".view-profile", async function () {
    const cid = $(this).data("info");
    fidgetSpinner(".profile-page-container");
    currentTab = ".profile-page-container";
    $(".profile-search-input").slideDown(250);
    $(".profile-search-input").css("display", "block");
    $("#profile-search-input:text").val(cid.toString());
    canSearchForProfiles = false;
    let result = await $.post(
      `https://${GetParentResourceName()}/searchProfiles`,
      JSON.stringify({
        name: cid,
      })
    );

    searchProfilesResults(result);
  });

  $(".contextmenu").on("click", ".view-incident2", function () {
    const incidentId = $(this).data("info");
    fidgetSpinner(".incidents-page-container");
    currentTab = ".incidents-page-container";
    $(".close-all").css("filter", "none");
    $(".incidents-known-container").fadeOut(250);
    setTimeout(() => {
      $(".incidents-search-input").slideDown(250);
      $(".incidents-search-input").css("display", "block");
      setTimeout(() => {
        $("#incidents-search-input:text").val(incidentId.toString());
        canSearchForProfiles = false;
        $.post(
          `https://${GetParentResourceName()}/searchIncidents`,
          JSON.stringify({
            incident: incidentId.toString(),
          })
        );
        $(".incidents-items").empty();
        $(".incidents-items").prepend(
          `<div class="profile-loader"></div>`
        );
        setTimeout(() => {
          $.post(
            `https://${GetParentResourceName()}/getIncidentData`,
            JSON.stringify({
              id: incidentId.toString(),
            })
          );
        }, 250);
      }, 250);
    }, 250);
  });
  $(".profile-incidents-holder").on("contextmenu", ".white-tag", function (e) {
    const args = [
      {
        className: "view-incident2",
        icon: "fas fa-search",
        text: `View Incident #${$(this).data("id")}`,
        info: $(this).data("id"),
        status: "",
      },
    ];
    openContextMenu(e, args);
  });

  $(".contextmenu").on("click", ".view-incident", function () {
    const incidentId = $(this).data("info");
    fidgetSpinner(".incidents-page-container");
    currentTab = ".incidents-page-container";
    setTimeout(() => {
      $(".incidents-search-input").slideDown(250);
      $(".incidents-search-input").css("display", "block");
      setTimeout(() => {
        $(".close-all").css("filter", "none");
        $("#incidents-search-input:text").val(incidentId.toString());
        canSearchForProfiles = false;
        $.post(
          `https://${GetParentResourceName()}/searchIncidents`,
          JSON.stringify({
            incident: incidentId.toString(),
          })
        );
        $(".incidents-items").empty();
        $(".incidents-items").prepend(
          `<div class="profile-loader"></div>`
        );
        setTimeout(() => {
          $.post(
            `https://${GetParentResourceName()}/getIncidentData`,
            JSON.stringify({
              id: incidentId.toString(),
            })
          );
        }, 250);
      }, 250);
    }, 250);
  });
  $(".warrants-items").on("contextmenu", ".warrants-item", function (e) {
    //let information = $(this).html()
    //if (information) {
    args = [
      {
        className: "view-profile",
        icon: "far fa-eye",
        text: "View Profile",
        info: $(this).data("cid"),
        status: "",
      },
      {
        className: "view-incident",
        icon: "fas fa-search",
        text: `View Incident #${$(this).data("id")}`,
        info: $(this).data("id"),
        status: "",
      },
    ];
    openContextMenu(e, args);
    //}
  });

  $(".contextmenu").on("click", ".toggle-duty", function () {
    let info = $(this).data("info");
    let currentStatus = $(`[data-id="${info}"]`)
      .find(".unit-status")
      .html();
    if (currentStatus == "10-8") {
      $(`[data-id="${info}"]`).find(".unit-status").html("10-7");
      $(`[data-id="${info}"]`)
        .find(".unit-status")
        .removeClass("green-status")
        .addClass("yellow-status");
      $.post(
        `https://${GetParentResourceName()}/toggleDuty`,
        JSON.stringify({
          cid: info,
          status: 0,
        })
      );
    } else if (currentStatus == "10-7") {
      $(`[data-id="${info}"]`).find(".unit-status").html("10-8");
      $(`[data-id="${info}"]`)
        .find(".unit-status")
        .removeClass("yellow-status")
        .addClass("green-status");
      $.post(
        `https://${GetParentResourceName()}/toggleDuty`,
        JSON.stringify({
          cid: info,
          status: 1,
        })
      );
    }
  });

  $(".contextmenu").on("click", ".set-callsign", function () {
    let info = $(this).data("info");
    $(".callsign-container").fadeIn(0);
    $(".callsign-inner-container").slideDown(500);
    $(".callsign-inner-container").fadeIn(500);
    $(".callsign-container").data("id", info);
  });

  $(".contextmenu").on("click", ".set-radio", function () {
    let info = $(this).data("info");
    $(".radio-container").fadeIn(0);
    $(".radio-inner-container").slideDown(500);
    $(".radio-inner-container").fadeIn(500);
    $(".radio-container").data("id", info);
  });

  $(".contextmenu").on("click", ".set-waypoint", function () {
    let info = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/setWaypointU`,
      JSON.stringify({
        cid: info,
      })
    );
  });

  $(".active-unit-list").on("contextmenu", ".active-unit-item", function (e) {
    let cid = $(this).data("id");
    if (cid) {
      args = [
        {
          className: "toggle-duty",
          icon: "fas fa-thumbtack",
          text: "Toggle Duty",
          info: cid,
          status: "",
        },
        {
          className: "set-callsign",
          icon: "far fa-id-badge",
          text: "Set Callsign",
          info: cid,
          status: "",
        },
        {
          className: "set-radio",
          icon: "fas fa-broadcast-tower",
          text: "Set Radio",
          info: cid,
          status: "",
        },
        {
          className: "set-waypoint",
          icon: "fas fa-map-marker-alt",
          text: "Set Waypoint",
          info: cid,
          status: "",
        },
      ];
      openContextMenu(e, args);
    }
  });

  $(".contextmenu").on("click", ".Set-Waypoint", function () {
    const callId = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/setWaypoint`,
      JSON.stringify({
        callid: callId,
      })
    );
  });

  $(".contextmenu").on("click", ".remove-blip", function () {
    const callId = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/removeCallBlip`,
      JSON.stringify({
        callid: callId,
      })
    );
  });

  $(".contextmenu").on("click", ".attached-units", function () {
    const callId = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/attachedUnits`,
      JSON.stringify({
        callid: callId,
      })
    );
  });

  $("#respondcalls").keydown(function (e) {
    const keyCode = e.which || e.keyCode;
    if (keyCode === 13 && !e.shiftKey) {
      const callid = $(".respond-calls-container").data("id");
      e.preventDefault();
      const time = new Date();
      $.post(
        `https://${GetParentResourceName()}/sendCallResponse`,
        JSON.stringify({
          message: $(this).val(),
          time: time.getTime(),
          callid: callid,
        })
      );
      $(this).val("");
    }
  });

  $(".contextmenu").on("click", ".respond-call", function () {
    const callId = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/getCallResponses`,
      JSON.stringify({
        callid: callId,
      })
    );
    /**$(".respond-calls").fadeIn(0)
    $(".respond-calls-container").fadeIn(250)
    $(".close-all").css("filter", "brightness(15%)");
    $("#respondcalls").val("")*/
  });

  $('#vehiclePointsSlider').change(function(){
    var currentValue = $('#vehiclePointsSliderValue');
    currentValue.html(this.value);
  });


  $(".active-calls-list").on(
    "contextmenu",
    ".active-calls-item",
    function (e) {
      const callId = $(this).data("id");
      const canRespond = $(this).data("canrespond");

      if (callId) {
        if (canRespond == true) {
          args = [
            {
              className: "attached-units",
              icon: "fas fa-link",
              text: "Attached Units",
              info: callId,
              status: "",
            },
            {
              className: "Set-Waypoint",
              icon: "fas fa-map-marker-alt",
              text: "Set Waypoint",
              info: callId,
              status: "",
            },
            {
              className: "remove-blip",
              icon: "fa-solid fa-circle-minus",
              text: "Remove Blip",
              info: callId,
              status: "",
            },
          ];
        } else if (canRespond == false) {
          args = [
            {
              className: "attached-units",
              icon: "fas fa-link",
              text: "Attached Units",
              info: callId,
              status: "",
            },
            {
              className: "Set-Waypoint",
              icon: "fas fa-map-marker-alt",
              text: "Set Waypoint",
              info: callId,
              status: "",
            },
            {
              className: "remove-blip",
              icon: "fa-solid fa-circle-minus",
              text: "Remove Blip",
              info: callId,
              status: "",
            },
          ];
        }
        openContextMenu(e, args);
      }
    }
  );

  $(".contextmenu").on("click", ".call-dispatch-detach", function () {
    const cid = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/callDispatchDetach`,
      JSON.stringify({
        callid: $(".dispatch-attached-units-container").attr("id"),
        cid: cid,
      })
    );
    $(".dispatch-attached-unit-item").filter(`[data-id="${cid}"]`).remove();
  });

  $(".contextmenu").on("click", ".Set-Dispatch-Waypoint", function () {
    const cid = $(this).data("info");
    $.post(
      `https://${GetParentResourceName()}/setDispatchWaypoint`,
      JSON.stringify({
        callid: $(".dispatch-attached-units-container").attr("id"),
        cid: cid,
      })
    );
  });

  $(".dispatch-attached-units-holder").on(
    "contextmenu",
    ".dispatch-attached-unit-item",
    function (e) {
      const cid = $(this).data("id");
      if (cid) {
        args = [
          {
            className: "set-waypoint",
            icon: "fas fa-map-marker-alt",
            text: "Set Waypoint",
            info: cid,
            status: "",
          },
        ];
        openContextMenu(e, args);
      }
    }
  );

  $(".contextmenu").on("click", ".dispatch-reply", function () {
    const callsign = $(this).data("info");
    const currVal = $(".dispatch-input").val();
    if (currVal === "") {
      $(".dispatch-input").val(callsign + " ");
    } else {
      $(".dispatch-input").val(currVal + " " + callsign + " ");
    }
    $(".dispatch-input").focus();
  });

  $(".dispatch-items").on(
    "contextmenu",
    ".dispatch-item-message",
    function (e) {
      const Callsign = $(this).data("author");

      var mySubString = Callsign.substring(
        Callsign.indexOf("(") + 1,
        Callsign.lastIndexOf(")")
      );

      args = [
        {
          className: "dispatch-reply",
          icon: "fas fa-reply",
          text: "Reply",
          info: mySubString,
          status: "",
        },
      ];
      openContextMenu(e, args);
    }
  );

  $(".callsign-buttons").on("click", ".callsign-cancel", function () {
    $(".callsign-inner-container").slideUp(500);
    $(".callsign-inner-container").fadeOut(500);
    setTimeout(() => {
      $(".callsign-container").slideUp(500);
      $(".callsign-container").fadeOut(500);
      $(".callsign-input").val("");
    }, 500);
  });

  $(".callsign-buttons").on("click", ".callsign-submit", function () {
    const callsign = $(".callsign-input").val();
    if (callsign.length > 2) {
      let editingcallsign = $(".callsign-container").data("id");
      let name = $(`[data-id="${editingcallsign}"]`)
        .find(".unit-name")
        .html()
        .replace(/\s*(?:\[[^\]]*\]|\([^)]*\))\s*/g, "");
      let newunitname = `(${callsign}) ${name}`;
      $(`[data-id="${editingcallsign}"]`)
        .find(".unit-name")
        .html(newunitname);
      $.post(
        `https://${GetParentResourceName()}/setCallsign`,
        JSON.stringify({
          cid: editingcallsign,
          newcallsign: callsign,
        })
      );

      $(".callsign-inner-container").slideUp(500);
      $(".callsign-inner-container").fadeOut(500);
      setTimeout(() => {
        $(".callsign-container").slideUp(500);
        $(".callsign-container").fadeOut(500);
        $(".callsign-input").val("");
      }, 500);
    }
  });

  $(".radio-buttons").on("click", ".radio-cancel", function () {
    $(".radio-inner-container").slideUp(500);
    $(".radio-inner-container").fadeOut(500);
    setTimeout(() => {
      $(".radio-container").slideUp(500);
      $(".radio-container").fadeOut(500);
      $(".radio-input").val("");
    }, 500);
  });

  $(".radio-buttons").on("click", ".radio-submit", function () {
    const radio = $(".radio-input").val();
    if (radio.length > 0) {
      let editingradio = $(".radio-container").data("id");
      let newunitname = `${radio}`;
      $(`[data-id="${editingradio}"]`)
        .find(".unit-radio")
        .html(newunitname);
      $.post(
        `https://${GetParentResourceName()}/setRadio`,
        JSON.stringify({
          cid: editingradio,
          newradio: radio,
        })
      );

      $(".radio-inner-container").slideUp(500);
      $(".radio-inner-container").fadeOut(500);
      setTimeout(() => {
        $(".radio-container").slideUp(500);
        $(".radio-container").fadeOut(500);
        $(".radio-input").val("");
      }, 500);
    }
  });

  $(".cams-items").click(function () {
    var camId = this.id;
    $.post(
      `https://${GetParentResourceName()}/openCamera`,
      JSON.stringify({
        cam: camId,
      })
    );
    $.post(`https://${GetParentResourceName()}/escape`, JSON.stringify({}));
  })

  var draggedElement = 0;
  var dragging = false;

  $(".active-unit-list").on("click", ".active-unit-item", function (e) {
    if (dragging) {
      $("#draggedItem").css("opacity", 0.0);
      document.getElementById("draggedItem").innerHTML = "";
      dragging = false;
    } else {
      dragging = true;
      draggedElement = $(this).data("id");
      let draggedItemHtml = $(this).html();
      document.getElementById("draggedItem").innerHTML = draggedItemHtml;
      document.getElementById("draggedItem").style.left = "cursorX-50";
      document.getElementById("draggedItem").style.top = "cursorY-50";
      document.getElementById("draggedItem").style.opacity = "0.5";
    }
  });

  document.onmousemove = handleMouseMove;

  function handleMouseMove(event) {
    let dot, eventDoc, doc, body, pageX, pageY;
    event = event || window.event; // IE-ism
    if (event.pageX == null && event.clientX != null) {
      eventDoc = (event.target && event.target.ownerDocument) || document;
      doc = eventDoc.documentElement;
      body = eventDoc.body;

      event.pageX =
        event.clientX +
        ((doc && doc.scrollLeft) || (body && body.scrollLeft) || 0) -
        ((doc && doc.clientLeft) || (body && body.clientLeft) || 0);
      event.pageY =
        event.clientY +
        ((doc && doc.scrollTop) || (body && body.scrollTop) || 0) -
        ((doc && doc.clientTop) || (body && body.clientTop) || 0);
    }

    if (dragging) {
      cursorX = event.pageX;
      cursorY = event.pageY;
      document.getElementById("draggedItem").style.left =
        "" + cursorX - 50 + "px";
      document.getElementById("draggedItem").style.top =
        "" + cursorY - 50 + "px";
    }
  }

  $(".active-calls-list").on("click", ".active-calls-item", function (e) {
    const callId = $(this).data("id");
    $("#draggedItem").css("opacity", 0.0);
    document.getElementById("draggedItem").innerHTML = "";
    dragging = false;
    if (callId && draggedElement) {
      $.post(
        `https://${GetParentResourceName()}/callDragAttach`,
        JSON.stringify({
          callid: callId,
          cid: draggedElement,
        })
      );
      draggedElement = 0;
    }
  });
  const customThemes = {
    lspd: {
      color1: "#1E3955",
      color2: "#213f5f",
      color3: "#2C537B",
      color4: "#23405E",
      color5: "#152638",
      color6: "#121f2c",
      color7: "rgb(28, 54, 82)",
      color8: "#2554cc",
      color9: "#6E707C",
      color10: "#8F741B",
      image: "img/LSPD.webp",
      name: "LOS SANTOS POLICE",
    },
    bcso: {
      color1: "#333333",
      color2: "#57471a",
      color3: "#614f1d",
      color4: "#594b27",
      color5: "#4d3f17",
      color6: "#433714",
      color7: "#57471a",
      color8: "#2554cc",
      color9: "#6E707C",
      color10: "#8F741B",
      image: "img/BCSO.webp",
      name: "BLAINE COUNTY SHERIFF OFFICE",
    },
    sasp: {
      color1: "#423f39",
      color2: "#8f7c3f",
      color3: "#16537e",
      color4: "#8f7c3f",
      color5: "#0f3a58",
      color6: "#121f2c",
      color7: "#0f3a58",
      color8: "#2554cc",
      color9: "#9c9485",
      color10: "#8F741B",
      image: "img/sasp_badge.webp",
      name: "SAN ANDREAS STATE POLICE",
    },
    sast: {
      color1: "#2c2c2c",
      color2: "#232323",
      color3: "#16537e",
      color4: "#1c1c1c",
      color5: "#232323",
      color6: "#121f2c",
      color7: "#232323",
      color8: "#2554cc",
      color9: "#bcbcbc",
      color10: "#8F741B",
      image: "img/sast_badge.webp",
      name: "SAN ANDREAS STATE TROOPERS",
    },
    sapr: {
      color1: "#3b4c3a",
      color2: "#57471a",
      color3: "#614f1d",
      color4: "#594b27",
      color5: "#4d3f17",
      color6: "#433714",
      color7: "#57471a",
      olor8: "#2554cc",
      color9: "#6E707C",
      color10: "#8F741B",
      image: "img/sapr.webp",
      name: "SAN ANDREAS PARK RANGERS",
    },
    lssd: {
      color1: "#3b4c3a",
      color2: "#8f7c3f",
      color3: "#8f7c3f",
      color4: "#806f38",
      color5: "#4d3f17",
      color6: "#f1c232",
      color7: "#57471a",
      color8: "#2554cc",
      color9: "#6E707C",
      color10: "#8F741B",
      image: "img/LSSD.webp",
      name: "LOS SANTOS SHERIFF DEPARTMENT",
    },
    doc: {
      color1: "#191919",
      color2: "#323232",
      color3: "#000000",
      color4: "#666666",
      color5: "#46474f",
      color6: "#191919",
      color7: "#666666",
      color8: "#2554cc",
      color9: "#6E707C",
      color10: "#8F741B",
      image: "img/BBSP.webp",
      name: "DEPARTMENT OF CORRECTIONS",
    },
    ambulance: {
      color1: "#5F2121",
      color2: "#7B2C2C",
      color3: "#4A1C1C",
      color4: "#5E2323",
      color5: "#381515",
      color6: "#2C1212",
      color7: "#521C1C",
      color8: "#CC2525",
      color9: "#8A8D91",
      color10: "#444444",
      image: "img/ems_badge.webp",
      name: "PILLBOX HILL MEDICAL CENTER",
    },
    doj: {
      color1: "#553a1e",
      color2: "#5f4321",
      color3: "#7b552c",
      color4: "#5e4123",
      color5: "#382815",
      color6: "#2c2312",
      color7: "rgb(82, 60, 28)",
      color8: "#cc9225",
      color9: "#6E707C",
      color10: "#8F741B",
      image: "img/court.webp",
      name: "DEPARTMENT OF JUSTICE",
    },
  }
  function applyCustomTheme(theme) {
    document.documentElement.style.setProperty(
      "--color-1", /* Panels */
        theme.color1
        );
    document.documentElement.style.setProperty(
      "--color-2", /* Clock */
        theme.color2
        );
    document.documentElement.style.setProperty(
      "--color-3", /* Outlines and hover */
        theme.color3
        );
    document.documentElement.style.setProperty(
      "--color-4", /* Button Base */
        theme.color4
        );
    document.documentElement.style.setProperty(
        "--color-5",
        theme.color5
        );
    document.documentElement.style.setProperty(
        "--color-6",
        theme.color6
        );
    document.documentElement.style.setProperty(
        "--color-7",
        theme.color7
        );
    document.documentElement.style.setProperty(
        "--color-8",
        theme.color8
        );
    document.documentElement.style.setProperty(
        "--color-9",
        theme.color9
        );
    document.documentElement.style.setProperty(
        "--color-10",
        theme.color10
        );
      $(".badge-logo").attr("src", theme.image );
      $(".header-title").html(theme.name);
  }
  function JobColors(sentJob) {
    if (sentJob) {
      if (PoliceJobs[sentJob] !== undefined)  {
        if (sentJob == "police") {
            applyCustomTheme(customThemes.lspd)
          } else if (sentJob == "bcso"){
            applyCustomTheme(customThemes.bcso)
          } else if (sentJob == "sasp") {
            applyCustomTheme(customThemes.sasp)
          } else if (sentJob == "sast") {
            applyCustomTheme(customThemes.sast)

          } else if (sentJob == "sapr") {
            applyCustomTheme(customThemes.sapr)
          } else if (sentJob == "lssd") {
            applyCustomTheme(customThemes.lssd)
          } else if (sentJob == "doc") {
            applyCustomTheme(customThemes.doc)
          }
        $(".bolo-nav-item").html("BOLOs");
        $(".bolos-search-title").html("Bolos");
        $("#bolos-search-input").attr("placeholder", "Search Bolo...");
        $(".manage-bolos-title").html("Manage Bolo");
        $(".manage-bolos-editing-title").html(
          "You are currently creating a new BOLO"
        );
        $(".boloplate-title").html("Plate");
        $(".boloowner-title").html("Owner");
        $(".boloindividual-title").html("Individual");
        $("#boloplate").attr("placeholder", "Place plate here...");
        $("#bolodetail").attr(
          "placeholder",
          "Bolo detail goes here..."
        );
        $("#boloowner").attr(
          "placeholder",
          "Place vehicle owner here..."
        );
        $("#boloindividual").attr(
          "placeholder",
          "Place invidivual here..."
        );
        $("#home-warrants-container").fadeIn(0);
        $("#home-reports-container").fadeOut(0);
        //$(".quote-span").html("TUCKER MALD, BEST MALD");
        $(".incidents-nav-item").show();
        $(".bolo-nav-item").show();
        $(".dmv-nav-item").show();
        $(".weapons-nav-item").show()
        $(".cams-nav-item").show();
        $(".map-nav-item").show();
        $(".dispatch-title-ofsomesort").html("Dispatch");
        $(".dispatch-comms-container").fadeIn(0);
        $(".manage-profile-name-input-1").attr("readonly", true);
        $(".manage-profile-name-input-2").attr("readonly", true);
        $("#reports-officers-involved-tag-title").html(
          "Officers Involved"
        );
        $("#bolos-officers-involved-tag-title").html(
          "Officers Involved"
        );
        $(".roster-iframe").attr("src", rosterLink);
        $(".sop-iframe").attr("src", sopLink);

        $(".manage-profile-save").css("display", "block");
        $(".manage-profile-editing-title").css("display", "block");
        $(".manage-incidents-create").css("display", "block");
        $(".manage-incidents-save").css("display", "block");
        $(".manage-incidents-editing-title").css("display", "block");
        $(".manage-reports-new").css("display", "block");
        $(".manage-reports-save").css("display", "block");
        $(".manage-reports-editing-title").css("display", "block");
        $(".vehicle-information-save").css("display", "block");
        $(".vehicle-information-title").css("margin-right", "0px").css("width", "81%");
        $(".manage-incidents-title ").css("margin-right", "0px")
        $(".manage-reports-title").css("margin-right", "0px").css("width", "66%");
      } else if (AmbulanceJobs[sentJob] !== undefined) {
        $(".weapons-nav-item").hide()
        $("#home-warrants-container").fadeOut(0);
        $("#home-reports-container").fadeIn(0);
        if (sentJob == "ambulance") {
          applyCustomTheme(customThemes.ambulance)
        }
        //$(".quote-span").html("The simplest explanation is almost always somebody screwed up.");
        $(".bolo-nav-item").html("ICU");
        $(".bolos-search-title").html("ICU Check-ins");
        $("#bolos-search-input").attr(
          "placeholder",
          "Search Check-ins..."
        );
        $(".manage-bolos-title").html("Manage ICU Check-in");
        $(".manage-bolos-editing-title").html(
          "You are creating a new ICU Check-in"
        );
        $(".boloplate-title").html("Estimated Recovery");
        $(".boloowner-title").html("Emergency Contact");
        $(".boloindividual-title").html("Patient");
        $("#boloplate").attr(
          "placeholder",
          "Enter recovery time here..."
        );
        $("#bolodetail").attr(
          "placeholder",
          "Enter ICU Check-in details here..."
        );
        $("#boloowner").attr(
          "placeholder",
          "Enter emergency contact here..."
        );
        $("#boloindividual").attr(
          "placeholder",
          "Enter patient name and CID here..."
        );
        $(".incidents-nav-item").hide();
        $(".dmv-nav-item").hide();
        $(".cams-nav-item").hide();
        $("#reports-officers-involved-tag-title").html(
          "EMS Involved"
        );
        $("#bolos-officers-involved-tag-title").html(
          "EMS Involved"
        );
        $(".dispatch-title-ofsomesort").html("Dispatch");
        $(".dispatch-comms-container").fadeIn(0);
        $(".manage-profile-name-input-1").attr("readonly", true);
        $(".manage-profile-name-input-2").attr("readonly", true);
        $(".roster-iframe").attr("src", rosterLink);
        $(".sop-iframe").attr("src", sopLink);

        $(".manage-profile-save").css("display", "block");
        $(".manage-profile-editing-title").css("display", "block");
        $(".manage-incidents-create").css("display", "block");
        $(".manage-incidents-save").css("display", "block");
        $(".manage-incidents-editing-title").css("display", "block");
        $(".manage-reports-new").css("display", "block");
        $(".manage-reports-save").css("display", "block");
        $(".manage-reports-editing-title").css("display", "block");
        $(".vehicle-information-save").css("display", "block");
        $(".vehicle-information-title").css("margin-right", "0px").css("width", "81%");
        $(".manage-incidents-title ").css("margin-right", "0px")
        $(".manage-reports-title").css("margin-right", "0px").css("width", "66%");
      } else if (DojJobs[sentJob] !== undefined) {
        applyCustomTheme(customThemes.doj)
        //$(".quote-span").html("Actually useless.");
        //$(".dmv-nav-item").hide();
        $(".weapons-nav-item").show()
        $(".bolo-nav-item").hide();
        $(".dispatch-title-ofsomesort").html("Message Board");
        $(".dispatch-comms-container").fadeOut(0);
        $(".manage-profile-name-input-1").attr("readonly", false);
        $(".manage-profile-name-input-2").attr("readonly", false);
        $("#home-warrants-container").css("height", "98%");
        $(".roster-iframe").attr("src", rosterLink);
        $(".sop-iframe").attr("src", sopLink);

        $(".manage-profile-save").css("display", "none");
        $(".manage-profile-editing-title").css("display", "none");
        $(".manage-incidents-create").css("display", "none");
        $(".manage-incidents-title").css("margin-right", "auto");
        $(".manage-incidents-title").css("width", "95%");
        $(".manage-incidents-save").css("display", "none");
        $(".manage-incidents-editing-title").css("display", "none");
        $(".manage-reports-new").css("display", "none");
        $(".manage-reports-save").css("display", "none");
        $(".manage-reports-editing-title").css("display", "none");
        $(".vehicle-information-save").css("display", "none");
        $(".vehicle-information-title").css("margin-right", "auto").css("width", "95%");
        $(".manage-incidents-title ").css("margin-right", "auto")
        $(".manage-reports-title").css("margin-right", "auto").css("width", "95%");
      }
    }
  }
{/* <div class="bulletin-id">ID: ${value.id}</div> */}
window.addEventListener("message", function (event) {
    let eventData = event.data;
    $(".dispatch-msg-notif").fadeIn(500);
    if (eventData.type == "show") {
      if (eventData.enable == true) {
        rosterLink = eventData.rosterLink;
        sopLink = eventData.sopLink;
        playerJob = eventData.job;
        PlayerJobType = eventData.jobType;

        JobColors(playerJob);
        $(".quote-span").html(randomizeQuote());
        if (PoliceJobs[playerJob] !== undefined || DojJobs[playerJob] !== undefined) {
          $(".manage-profile-licenses-container").removeClass("display_hidden");
          $(".manage-profile-vehs-container").removeClass("display_hidden");
          $(".manage-profile-houses-container").removeClass("display_hidden");
        }

        $("body").fadeIn(0);
        $(".close-all").css("filter", "none");
        $(".close-all").fadeOut(0);
        if (!currentTab) {
          currentTab = ".dashboard-page-container";
        }
        $(currentTab).slideDown(250);
        timeShit();
      } else {
        $(".callsign-inner-container").fadeOut(0);
        $(".callsign-container").fadeOut(0);
        $(".radio-inner-container").fadeOut(0);
        $(".radio-container").fadeOut(0);
        $(".incidents-person-search-container").fadeOut(0);
        $(".dispatch-attached-units").fadeOut(0);
        $(".respond-calls").fadeOut(0);
        $(".respond-calls-container").fadeOut(0);
        $("body").slideUp(250);
        $(".close-all").slideUp(250);
      }
    } else if (eventData.type == "data") {
      $(".name-shit").html(eventData.name);
      $(".header-location").html(" " + eventData.location);
      MyName = eventData.fullname;

      $(".bulletin-items-continer").empty();
      $.each(eventData.bulletin, function (index, value) {
        $(
          ".bulletin-items-continer"
        ).prepend(`<div class="bulletin-item" data-id=${value.id} data-title=${value.title}>
                <div class="bulletin-item-title">${value.title}</div>
                <div class="bulletin-item-info">${value.desc}</div>
                <div class="bulletin-bottom-info">
                    <div class="bulletin-date">${value.author
          } - ${timeAgo(Number(value.time))}</div>
                </div>
                </div>`);
      });

      let policeCount = 0;
      let saspCount = 0;
      let bcsoCount = 0;
      let emsCount = 0;
      let dojCount = 0;
     /*  let fireCount = 0; */

      let activeUnits = eventData.activeUnits;
      let cid = eventData.citizenid;
      let onDutyOnly = eventData.ondutyonly;
      $(".active-unit-list").html(' ');
      let unitListHTML = '';

      activeUnits = Object.values(activeUnits)
      activeUnits.forEach((unit) => {
        if (onDutyOnly && unit.duty == 0 && unit.cid != cid) {
          return
        }
        let status = unit.duty == 1 ? "10-8" : '10-7';
        let statusColor = unit.duty == 1 ? "green-status" : 'yellow-status';
        let radioBack = unit.sig100 ? "#7b2c2c" : "var(--color-3)";
        let radio = unit.radio ? unit.radio : "0";
        let callSign = unit.callSign ? unit.callSign : "000";
        let activeInfoJob = `<div class="unit-job active-info-job-unk">UNKNOWN</div>`;
        if (PoliceJobs[unit.unitType] !== undefined) {
          if (unit.unitType == "police") { policeCount++;
          activeInfoJob = `<div class="unit-job active-info-job-lspd">LSPD</div>`;
          } else if(unit.unitType == "bcso")  { bcsoCount++;
            activeInfoJob = `<div class="unit-job active-info-job-bcso">BCSO</div>`;
          } else if(unit.unitType == "lssd")  { bcsoCount++;
            activeInfoJob = `<div class="unit-job active-info-job-bcso">LSSD</div>`;
          } else if(unit.unitType == "sasp")  { saspCount++;
            activeInfoJob = `<div class="unit-job active-info-job-sasp">SASP</div>`;
          } else if(unit.unitType == "sast")  { saspCount++;
            activeInfoJob = `<div class="unit-job active-info-job-sasp">SAST</div>`;
          } else if(unit.unitType == "sapr")  { saspCount++;
            activeInfoJob = `<div class="unit-job active-info-job-sapr">SAPR</div>`;
          } else if(unit.unitType == "judge")  { dojCount++;
            activeInfoJob = `<div class="unit-job active-info-job-doj">DOJ</div>`;
          } else if(unit.unitType == "doc")  { dojCount++;
            activeInfoJob = `<div class="unit-job active-info-job-doc">DOC</div>`;
          }
        } else if (AmbulanceJobs[unit.unitType] !== undefined) {
          activeInfoJob = `<div class="unit-job active-info-job-ambulance">Ambulance</div>`
          emsCount++;
        } else if (DojJobs[unit.unitType] !== undefined) {
          activeInfoJob = `<div class="unit-job active-info-job-doj">DOJ</div>`
          dojCount++;
        }

        unitListHTML += `
                    <div class="active-unit-item" data-id="${unit.cid}">
                        <div class="unit-status ${statusColor}">${status}</div>
                        ${activeInfoJob}
                        <div class="unit-name">(${callSign}) ${unit.firstName} ${unit.lastName}</div>
                        <div class="unit-radio" style="background-color: ${radioBack};">${radio}</div>
                    </div>
                `;
      });

      $(".active-unit-list").html(unitListHTML)


      $("#police-count").html(policeCount);
      $("#sasp-count").html(saspCount);
      $("#bcso-count").html(bcsoCount);
      $("#ems-count").html(emsCount);
      $("#doj-count").html(dojCount);

    } else if (eventData.type == "newBulletin") {
      const value = eventData.data;
      $(".bulletin-items-continer")
        .prepend(`<div class="bulletin-item" data-id=${value.id}>
                <div class="bulletin-item-title">${value.title}</div>
                <div class="bulletin-item-info">${value.info}</div>
                <div class="bulletin-bottom-info">
                    <div class="bulletin-id">ID: ${value.id}</div>
                    <div class="bulletin-date">${value.author} - ${timeAgo(
          Number(value.time)
        )}</div>
                </div>
            </div>`);
    } else if (eventData.type == "deleteBulletin") {
      $(".bulletin-items-continer")
        .find("[data-id='" + eventData.data + "']")
        .remove();
    } else if (eventData.type == "warrants") {
      $(".warrants-items").empty();
      $.each(eventData.data, function (index, value) {
        $('.warrants-items').prepend(`<div class="warrants-item" data-cid=${value.cid} data-id=${value.linkedincident}><div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 0.75vh; width: 100%;">
            <div style="display: flex; flex-direction: column;">
                <div class="warrant-title">${value.name}</div>
            </div>
            <div class="warrant-bottom-info">
                <div class="warrant-id">Incident ID: ${value.linkedincident}</div>
            </div>
        </div></div>`)
    })
    } else if (eventData.type == "dispatchmessages") {
      const table = eventData.data;
      LastName = "";
      DispatchNum = 0;
      $(".dispatch-items").empty();
      $.each(table, function (index, value) {
        DispatchNum = DispatchNum + 1;
        if (LastName == value.name) {
          $(".dispatch-items").append(`
                    <div class="dispatch-item-grid dispatch-item-msg">
                        <div class="dispatch-item-message" data-author="${value.name}">${value.message}</div>
                    </div>
                    `);
        } else {
          if (DispatchNum == 1) {
            $(".dispatch-items")
              .append(`<div class="dispatch-item" style="display: flex; margin-top: 0vh;" >
                        <img src="${value.profilepic
                }" class="dispatch-message-profilepic">
                        <div class="dispatch-item-grid">
                            <div class="dispatch-item-info dispatch-info-job-${value.job
                }"> ${value.name
                } <span style="color:#969696; margin-left: 0.5vh; font-size: 12px; font-weight: normal;">${timeAgo(
                  Number(value.time)
                )}</span> </div>
                            <div class="dispatch-item-message" data-author="${value.name
                }">${value.message}</div>
                        </div>
                        </div>`);
          } else {
            $(".dispatch-items")
              .append(`<div class="dispatch-item" style="display: flex;" >
                        <img src="${value.profilepic
                }" class="dispatch-message-profilepic">
                        <div class="dispatch-item-grid">
                            <div class="dispatch-item-info dispatch-info-job-${value.job
                }"> ${value.name
                } <span style="color:#969696; margin-left: 0.5vh; font-size: 12px; font-weight: normal;">${timeAgo(
                  Number(value.time)
                )}</span> </div>
                            <div class="dispatch-item-message" data-author="${value.name
                }">${value.message}</div>
                        </div>
                        </div>`);
          }
        }
        LastName = value.name;
        $(".dispatch-items").scrollTop(
          $(".dispatch-items")[0].scrollHeight
        );
      });
      $(".dispatch-items").scrollTop(
        $(".dispatch-items")[0].scrollHeight
      );
    } else if (eventData.type == "dispatchmessage") {
      const value = eventData.data;
      DispatchNum = DispatchNum + 1;
      const BodyDisplay = $("body").css("display");
      if (BodyDisplay == "block") {
        if (LastName == value.name) {
          $(".dispatch-items").append(`
                    <div class="dispatch-item-grid dispatch-item-msg">
                        <div class="dispatch-item-message" data-author="${value.name}">${value.message}</div>
                    </div>
                    `);
        } else {
          if (DispatchNum == 1) {
            $(".dispatch-items")
              .append(`<div class="dispatch-item" style="display: flex; margin-top: 0vh;" >
                        <img src="${value.profilepic
                }" class="dispatch-message-profilepic">
                        <div class="dispatch-item-grid">
                            <div class="dispatch-item-info dispatch-info-job-${value.job
                }"> ${value.name
                } <span style="color:#969696; margin-left: 0.5vh; font-size: 12px; font-weight: normal;">${timeAgo(
                  Number(value.time)
                )}</span> </div>
                            <div class="dispatch-item-message" data-author="${value.name
                }">${value.message}</div>
                        </div>
                        </div>`);
          } else {
            $(".dispatch-items")
              .append(`<div class="dispatch-item" style="display: flex;" >
                        <img src="${value.profilepic
                }" class="dispatch-message-profilepic">
                        <div class="dispatch-item-grid">
                            <div class="dispatch-item-info dispatch-info-job-${value.job
                }"> ${value.name
                } <span style="color:#969696; margin-left: 0.5vh; font-size: 12px; font-weight: normal;">${timeAgo(
                  Number(value.time)
                )}</span> </div>
                            <div class="dispatch-item-message" data-author="${value.name
                }">${value.message}</div>
                        </div>
                        </div>`);
          }
        }
        LastName = value.name;
      } else if (BodyDisplay == "none") {
        $.post(
          `https://${GetParentResourceName()}/dispatchNotif`,
          JSON.stringify({
            data: value,
          })
        );
      }
      $(".dispatch-items").scrollTop(
        $(".dispatch-items")[0].scrollHeight
      );
    } else if (eventData.type == "call") {
      const value = eventData.data;
      DispatchMAP(value);
      if (value && value?.job?.includes(playerJob) || value?.jobs.includes(PlayerJobType)) {
        const prio = value["priority"];
        let DispatchItem = `<div class="active-calls-item" data-id="${value.callId || value.id}" data-canrespond="false"><div class="active-call-inner-container"><div class="call-item-top"><div class="call-number">#${value.callId || value.id}</div><div class="call-code priority-${value.priority}">${value.dispatchCode || value.code}</div><div class="call-title">${value.dispatchMessage || value.message}</div><div class="call-radio">${value.units.length}</div></div><div class="call-item-bottom">`;

        if (
          value.dispatchCode == "911" ||
          value.dispatchCode == "311"
        ) {
          DispatchItem = `<div class="active-calls-item" data-id="${value.callId || value.id}" data-canrespond="true"><div class="active-call-inner-container"><div class="call-item-top"><div class="call-number">#${value.callId || value.id}</div><div class="call-code priority-${value.priority}">${value.dispatchCode || value.code}</div><div class="call-title">${value.dispatchMessage || value.message}</div><div class="call-radio">${value.units.length}</div></div><div class="call-item-bottom">`;
        }

        if (value["time"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-clock"></span>${timeAgo(
            value.time
          )}</div>`;
        }

        if (value["firstStreet"] || value['street']) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-map-pin"></span>${value.firstStreet || value.street}</div>`;
        }

        if (value['camId']) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-camera"></span>${value.camId}</div>`;
        }

        if (value["callsign"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-compass"></span>${value.callsign}</div>`;
        }

        if (value["doorCount"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-door-open"></span>${value.doorCount}</div>`;
        }

        if (value["speed"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-arrow-right"></span>${value.speed}</div>`;
        }

        if (value["weapon"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-bullseye"></span>${value.weapon}</div>`;
        }

        if (value["heading"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-share"></span>${value.heading}</div>`;
        }

        if (value["gender"]) {
          let gender = "Male";
          if (value["gender"] == 0 || value["gender"] == 2) {
            gender = "Female";
          }
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-genderless"></span>${gender}</div>`;
        }

        if (value["model"] && value["plate"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-car"></span>${value["model"]}<span class="fas fa-digital-tachograph" style="margin-left: 2vh;"></span>${value["plate"]}</div>`;
        } else if (value["plate"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-digital-tachograph"></span>${value["plate"]}</div>`;
        } else if (value["model"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-car"></span>${value["model"]}</div>`;
        }

        if (value["firstColor"] || value['color']) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-spray-can"></span>${value["firstColor"] || value['color']}</div>`;
        }

        if (value["automaticGunfire"] == true) {
          DispatchItem += `<div class="call-bottom-info"><span class="fab fa-blackberry"></span>Automatic Gunfire</div>`;
        }

        if (value["name"] && value["number"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="far fa-id-badge"></span>${value["name"]}<span class="fas fa-mobile-alt" style="margin-left: 2vh;"></span>${value["number"]}</div>`;
        } else if (value["number"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="fas fa-mobile-alt"></span>${value["number"]}</div>`;
        } else if (value["name"]) {
          DispatchItem += `<div class="call-bottom-info"><span class="far fa-id-badge"></span>${value["name"]}</div>`;
        }

        if (value["information"]) {
          DispatchItem += `<div class="call-bottom-info call-bottom-information"><span class="far fa-question-circle"></span>${value["information"]}</div>`;
        }

        DispatchItem += `</div></div></div>`;
        $(".active-calls-list").prepend(
          $(DispatchItem).hide().fadeIn("slow")
        );
      }
    } else if (eventData.type == "attachedUnits") {
      const table = eventData.data;
      if (table) {
        $(".dispatch-attached-units").fadeIn(0);
        $(".dispatch-attached-units-container").fadeIn(250);
        $(".close-all").css("filter", "brightness(15%)");
        $(".dispatch-attached-units-holder").empty();
        $.each(table, function (index, value) {
        const fullname = value.charinfo.firstname + ' ' + value.charinfo.lastname;
        const callsign = value.metadata.callsign;
        const jobLabel = value.job.label;
      
          $(".dispatch-attached-units-holder").prepend(
            `<div class="dispatch-attached-unit-item" data-id="${value.citizenid}">
              <div class="unit-job active-info-job-${value.job.name}">${jobLabel}</div>
              <div class="unit-name">(${callsign}) ${fullname}</div>
              <div class="unit-radio"><!-- Handle channel if available --></div>
            </div> `);
        });
        setTimeout(() => {
          $(".dispatch-attached-units-container").attr("id", eventData.callid);
        }, 1000);
      }
    } else if (eventData.type == "sendCallResponse") {
      if ($(".respond-calls-container").data("id") == eventData.callid) {
        $(".respond-calls-responses").prepend(
          `<div class="respond-calls-response"> ${eventData["name"]
          } responded "${eventData["message"]}" - ${timeAgo(
            Number(eventData.time)
          )}. </div>`
        );
      }
    } else if (eventData.type == "getCallResponses") {
      const table = eventData.data;
      $(".respond-calls").fadeIn(0);
      $(".respond-calls-container").fadeIn(250);
      $(".close-all").css("filter", "brightness(15%)");
      $("#respondcalls").val("");
      $(".respond-calls-responses").empty();
      setTimeout(() => {
        $(".respond-calls-container").data("id", eventData.callid);
      }, 1000);
      $.each(table, function (index, value) {
        $(".respond-calls-responses").prepend(
          `<div class="respond-calls-response"> ${value["name"]
          } responded "${value["message"]}" - ${timeAgo(
            Number(value.time)
          )}. </div>`
        );
      });
    } else if (eventData.type == "calls") {
      const table = eventData.data;
      $(".active-calls-list").empty();
      $.each(table, function (index, value) {
        if (value && value?.job?.includes(playerJob) || value?.jobs.includes(PlayerJobType)) {
          DispatchMAP(value);
          const prio = value["priority"];
          let DispatchItem = `<div class="active-calls-item" data-id="${value.callId || value.id}" data-canrespond="false"><div class="active-call-inner-container"><div class="call-item-top"><div class="call-number">#${value.callId || value.id}</div><div class="call-code priority-${value.priority}">${value.dispatchCode || value.code}</div><div class="call-title">${value.dispatchMessage || value.message}</div><div class="call-radio">${value.units.length}</div></div><div class="call-item-bottom">`;

          if (
            value.dispatchCode == "911" ||
            value.dispatchCode == "311"
          ) {
            DispatchItem = `<div class="active-calls-item" data-id="${value.callId || value.id}" data-canrespond="true"><div class="active-call-inner-container"><div class="call-item-top"><div class="call-number">#${value.callId || value.id}</div><div class="call-code priority-${value.priority}">${value.dispatchCode || value.code}</div><div class="call-title">${value.dispatchMessage || value.message}</div><div class="call-radio">${value.units.length}</div></div><div class="call-item-bottom">`;
          }

          if (value["time"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-clock" style="margin-left: -0.1vh;"></span>${timeAgo(
              value.time
            )}</div>`;
          }

          if (value["firstStreet"] || value['street']) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-map-pin"></span>${value.firstStreet || value.street}</div>`;
          }

          if (value['camId']) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-camera"></span>${value.camId}</div>`;
          }

          if (value["heading"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-share"></span>${value.heading}</div>`;
          }

          if (value["weapon"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-gun"></span>${value.weapon}</div>`;
          }

          if (value["gender"]) {
            let gender = "Male";
            if (value["gender"] == 0 || value["gender"] == 2) {
              gender = "Female";
            }
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-genderless"></span>${gender}</div>`;
          }

          if (value["model"] && value["plate"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-car"></span>${value["model"]}<span class="fas fa-digital-tachograph" style="margin-left: 2vh;"></span>${value["plate"]}</div>`;
          } else if (value["plate"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-digital-tachograph"></span>${value["plate"]}</div>`;
          } else if (value["model"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-car"></span>${value["model"]}</div>`;
          }

          if (value["firstColor"] || value["color"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-spray-can"></span>${value["firstColor"] || value["color"]}</div>`;
          }

          if (value["automaticGunfire"] == true) {
            DispatchItem += `<div class="call-bottom-info"><span class="fab fa-blackberry"></span>Automatic Gunfire</div>`;
          }

          if (value["name"] && value["number"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="far fa-id-badge"></span>${value["name"]}<span class="fas fa-mobile-alt" style="margin-left: 2vh;"></span>${value["number"]}</div>`;
          } else if (value["number"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="fas fa-mobile-alt"></span>${value["number"]}</div>`;
          } else if (value["name"]) {
            DispatchItem += `<div class="call-bottom-info"><span class="far fa-id-badge"></span>${value["name"]}</div>`;
          }

          if (value["information"]) {
            DispatchItem += `<div class="call-bottom-info call-bottom-information"><span class="far fa-question-circle"></span>${value["information"]}</div>`;
          }

          DispatchItem += `</div></div></div>`;
          $(".active-calls-list").prepend(
            $(DispatchItem).hide().fadeIn("slow")
          );
        }
      });
    } else if (eventData.type == "incidents") {
      let table = eventData.data;
      canSearchForProfiles = true;
      $(".incidents-items").empty();
      $.each(table, function (index, value) {
        $(".incidents-items").append(
          `<div class="incidents-item" data-id="${value.id}">
                    <div class="incidents-top-holder">
                        <div class="incidents-item-title">${value.title}</div>
                        <div class="incedent-report-name">Incident Report</div>
                    </div>
                    <div class="incidents-bottom-holder">
                        <div class="incedent-report-id">ID: ${value.id}</div>
                        <div class="incedent-report-time-ago">${value.author
          } - ${timeAgo(Number(value.time))}</div>
                    </div>
                </div>`
        );
      });
      $(".contextmenu").on("click", ".incidents-delete", function () {
        $(".incidents-items")
          .find(`[data-id="${$(this).data("info")}"]`)
          .remove();
        $.post(
          `https://${GetParentResourceName()}/deleteIncidents`,
          JSON.stringify({
            id: $(this).data("info"),
          })
        );
      });

      $(".incidents-items").on("contextmenu", ".incidents-item", function (e) {
        var args = "";
        args = [
          {
            className: "incidents-delete",
            icon: "fas fa-times",
            text: "Delete Incidents",
            info: $(this).data("id"),
            status: "",
          },
        ];
        openContextMenu(e, args);
      });
    } else if (eventData.type == "getPenalCode") {
      const titles = eventData.titles;
      const penalcode = eventData.penalcode;
      $(".offenses-main-container").empty();
      $.each(titles, function (index, value) {
        $(".offenses-main-container").append(
          `<div class="offenses-title-container">
                        <div class="offenses-title">${value}</div>
                    </div>
                    <div class="offenses-container offenses-prepend-holder" id="penal-${index}">
                    </div>
                    `
        );
      });
      $.each(penalcode, function (index, value) {
        $.each(value, function (i, v) {
          $(`#penal-${index}`).append(`
                    <div class="offense-item ${v.color}-penal-code" data-id="${index}.${i}" data-sentence="${v.months}" data-fine="${v.fine}" data-descr="${v.description}">
                    <div style="display: flex; flex-direction: row; width: 100%; margin: auto; margin-top: 0vh;">
                        <div class="offense-item-offense">${v.title}</div>
                        <div class="offfense-item-name">${v.class}</div>
                    </div>
                    <div style="display: flex; flex-direction: row; width: 100%; margin: auto; margin-bottom: 0vh; padding-top: 0.75vh;">
                        <div class="offense-item-id">${v.id}</div>
                        <div class="offfense-item-months">${v.months} Months - $${v.fine}</div>
                    </div>
                    `);
        });
      });
    } else if (eventData.type == "incidentData") {
      let table = eventData.data;

      $(".incidents-ghost-holder").html("");
      $(".associated-incidents-tags-holder").html("");

      $(".manage-incidents-editing-title").html(
        "You are currently editing incident " + table["id"]
      );
      $(".manage-incidents-editing-title").data(
        "id",
        Number(table["id"])
      );

      $(".manage-incidents-tags-add-btn").css("pointer-events", "auto");
      $(".manage-incidents-reports-content").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-officers-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-civilians-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-evidence-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".associated-incidents-tags-add-btn").css(
        "pointer-events",
        "auto"
      );


      $("#manage-incidents-title-input").val(table["title"]);
      $(".manage-incidents-reports-content").trumbowyg({
        changeActiveDropdownIcon: true,
        imageWidthModalEdit: true,
        btns: [
          ['foreColor', 'backColor','fontfamily','fontsize','indent', 'outdent'],
          ['strong', 'em',], ['insertImage'],
          ['viewHTML'],
          ['undo', 'redo'],
          ['formatting'],
          ['superscript', 'subscript'],
          ['link'],
          ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
          ['horizontalRule']
        ],
      });
      $(".manage-incidents-reports-content").trumbowyg('html', table["details"]);

      $(".manage-incidents-tags-holder").empty();
      $.each(table["tags"], function (index, value) {
        $(".manage-incidents-tags-holder").append(
          `<div class="manage-incidents-tag tag">${value}</div>`
        );
      });

      $(".manage-incidents-officers-holder").empty();
      $.each(table["officersinvolved"], function (index, value) {
        $(".manage-incidents-officers-holder").append(
          `<div class="tag">${value}</div>`
        );
      });

      $(".manage-incidents-civilians-holder").empty();
      $.each(table["civsinvolved"], function (index, value) {
        $(".manage-incidents-civilians-holder").append(
          `<div class="tag">${value}</div>`
        );
      });

      $(".manage-incidents-evidence-holder").empty();
      $.each(table["evidence"], function (index, value) {
        $(".manage-incidents-evidence-holder").append(
          `<img class="incidents-img" src=${value}>`
        );
      });

      $(".manage-incidents-title-holder").empty();
      if (PoliceJobs[playerJob] !== undefined || AmbulanceJobs[playerJob] !== undefined) {
        $(".manage-incidents-title-holder").prepend(
          `
            <div class="manage-incidents-title">Manage Incident</div>
            <div class="manage-incidents-create"> <span class="fas fa-plus" style="margin-top: 3.5px;"></span></div>
            <div class="manage-incidents-save"><span class="fas fa-save" style="margin-top: 3.5px;"></span></div>
            `
        );
        $(".manage-incidents-title").css("width", "66%");
        $(".manage-incidents-create").css("margin-right", "0px");
      } else if (DojJobs[playerJob] !== undefined) {
        $(".manage-incidents-title-holder").prepend(
          `
            <div class="manage-incidents-title">Manage Incident</div>
            `
        );
        $(".manage-incidents-title").css("width", "95%");
      }

      let associateddata = eventData.convictions;
      $.each(associateddata, function (index, value) {
        $(".associated-incidents-tags-holder").prepend(
          `<div class="associated-incidents-tag" data-id="${value.cid}">${value.name}</div>`
        );

        var warrantTag = "red-tag";
        var guiltyTag = "red-tag";
        var processedTag = "red-tag";
        var associatedTag = "red-tag";

        if (value.warrant == 1) {
          warrantTag = "green-tag";
        }
        if (value.guilty == 1) {
          guiltyTag = "green-tag";
        }
        if (value.processed == 1) {
          processedTag = "green-tag";
        }
        if (value.associated == 1) {
          associatedTag = "green-tag";
        }

        const cid = value.cid;

        // If the associated field is not checked, then populate the recommended fine and sentence fields
        const associatedIncidentsContainer = (value.associated != 1) && `
          <div class="associated-incidents-user-holder" data-name="${cid}" ></div>
          <div class="manage-incidents-title-tag" data-id="${cid}">Recommended Fine</div>
          <div class="associated-incidents-fine-input" data-id="${cid}"><img src="img/h7S5f9J.webp"> <input placeholder="0" disabled class="fine-recommended-amount" id="fine-recommended-amount" data-id="${cid}" type="number"></div>
          <div class="manage-incidents-title-tag" data-id="${cid}">Recommended Sentence</div>
          <div class="associated-incidents-sentence-input" data-id="${cid}"><img src="img/9Xn6xXK.webp"> <input placeholder="0" disabled class="sentence-recommended-amount" id="sentence-recommended-amount" data-id="${cid}" type="number"></div>
          <div class="manage-incidents-title-tag" data-id="${cid}">Fine</div>
          <div class="associated-incidents-fine-input" data-id="${cid}"><img src="img/h7S5f9J.webp"> <input placeholder="Enter fine here..." value="0" class="fine-amount" data-id="${cid}" type="number"></div>
          <div class="manage-incidents-title-tag" data-id="${cid}">Sentence</div>
          <div class="associated-incidents-sentence-input" data-id="${cid}"><img src="img/9Xn6xXK.webp"> <input placeholder="Enter months here..." value="0" class="sentence-amount" data-id="${cid}" type="number"></div>
          <div class="associated-incidents-controls" data-id="${cid}">
            <div id="jail-button" class="control-button" data-id="${cid}"><span class="fa-solid fa-building-columns" style="margin-top: 3.5px;"></span> Jail</div>
            <div id="fine-button" class="control-button" data-id="${cid}"><span class="fa-solid fa-file-invoice-dollar" style="margin-top: 3.5px;"></span> Fine</div>
            ${canSendToCommunityService ? `<div id="community-service-button" class="control-button" data-id="${cid}"> <span class="fa-solid fa-person-digging" style="margin-top: 3.5px;"></span>Community Service</div>` : ''}
          </div>
        `;

        $(".incidents-ghost-holder").prepend(
          `<div class="associated-incidents-user-container" data-id="${cid}">
              <div class="associated-incidents-user-title">${value.name} (#${cid})</div>
              <div class="associated-incidents-user-tags-holder">
                  <div class="associated-incidents-user-tag ${warrantTag}" data-id="${cid}">Warrant</div>
                  <div class="associated-incidents-user-tag ${guiltyTag}" data-id="${cid}">Guilty</div>
                  <div class="associated-incidents-user-tag ${processedTag}" data-id="${cid}">Processed</div>
                  <div class="associated-incidents-user-tag ${associatedTag}" data-id="${cid}">Associated</div>
              </div>
              <div class="modify-charges-label"><span class="fas fa-solid fa-info"></span> Right click below to add and/or modify charges.</div>
              ${associatedIncidentsContainer}
          </div>`
        );

        $(".fine-amount")
          .filter("[data-id='" + value.cid + "']")
          .val(value.fine);

        $(".sentence-amount")
          .filter("[data-id='" + value.cid + "']")
          .val(value.sentence);

        $(".fine-recommended-amount")
          .filter("[data-id='" + value.cid + "']")
          .val(value.recfine);

        $(".sentence-recommended-amount")
          .filter("[data-id='" + value.cid + "']")
          .val(value.recsentence);

        const charges = value["charges"];
        for (var i = 0; i < charges.length; i++) {
          const randomNum = Math.ceil(
            Math.random() * 1000
          ).toString();
          $(`[data-name="${cid}"]`).prepend(
            `<div class="white-tag" data-link="${randomNum}" data-id="${cid}">${charges[i]}</div>`
          );
        }
      });
    } else if (eventData.type == "incidentSearchPerson") {
      let table = eventData.data;
      $(".incidents-person-search-holder").empty();
      $.each(table, function (index, value) {
        let name = value.firstname + " " + value.lastname;
        $(".incidents-person-search-holder").prepend(
          `
            <div class="incidents-person-search-item" data-info="${name} (#${value.id})" data-cid="${value.id}" data-name="${name}" data-callsign="${value.callsign}">
                <img src="${value.profilepic}" class="incidents-person-search-item-pfp">
                <div class="incidents-person-search-item-right">
                    <div class="incidents-person-search-item-right-cid-title">Citizen ID</div>
                    <div class="incidents-person-search-item-right-cid-input"><span class="fas fa-id-card"></span> ${value.id}</div>
                    <div class="incidents-person-search-item-right-name-title">Name</div>
                    <div class="incidents-person-search-item-right-name-input"><span class="fas fa-user"></span> ${name}</div>
                </div>
            </div>
          `
        );
      });
    } else if (eventData.type == "boloData") {
      let table = eventData.data;
      $(".manage-bolos-editing-title").html(
        "You are currently editing BOLO " + table["id"]
      );

      if ($(".badge-logo").attr("src") == "img/ems_badge.webp") {
        $(".manage-bolos-editing-title").html(
          "You are editing ICU Check-in " + table["id"]
        );
      }

      $(".manage-bolos-editing-title").data("id", Number(table["id"]));

      $(".manage-bolos-input-title").val(table["title"]);
      $(".manage-bolos-input-plate").val(table["plate"]);
      $(".manage-bolos-input-owner").val(table["owner"]);
      $(".manage-bolos-input-individual").val(table["individual"]);

      $(".manage-bolos-reports-content").trumbowyg({
        changeActiveDropdownIcon: true,
        imageWidthModalEdit: true,
        btns: [
          ['foreColor', 'backColor','fontfamily','fontsize','indent', 'outdent'],
          ['strong', 'em',], ['insertImage'],
          ['viewHTML'],
          ['undo', 'redo'],
          ['formatting'],
          ['superscript', 'subscript'],
          ['link'],
          ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
          ['horizontalRule']
        ],
      });
      $(".manage-bolos-reports-content").trumbowyg('html', table["detail"]);

      $(".manage-bolos-tags-holder").empty();
      $.each(table["tags"], function (index, value) {
        $(".manage-bolos-tags-holder").prepend(
          `<div class="tag-bolo-input">${value}</div>`
        );
      });

      $(".bolo-gallery-inner-container").empty();
      $.each(table["gallery"], function (index, value) {
        let randomNum = Math.ceil(Math.random() * 10).toString();
        $(".bolo-gallery-inner-container").prepend(
          `<img src="${value}" class="bolo-img ${randomNum}" onerror="this.src='img/not-found.webp'">`
        );
      });

      $(".manage-officers-tags-holder").empty();
      $.each(table["officersinvolved"], function (index, value) {
        $(".manage-officers-tags-holder").prepend(
          `<div class="tag">${value}</div>`
        );
      });
    } else if (eventData.type == "bolos") {
      let table = eventData.data;
      var reportName = "General BOLO";
      canSearchForProfiles = true;
      $(".bolos-items").empty();
      if ($(".badge-logo").attr("src") == "img/ems_badge.webp") {
        reportName = "ICU Check-in";
      }
      $.each(table, function (index, value) {
        $(".bolos-items").prepend(
          `<div class="bolo-item" data-id="${value.id}">
                    <div class="bolo-top-holder">
                        <div class="bolo-item-title">${value.title}</div>
                        <div class="bolo-report-name">${reportName}</div>
                    </div>
                    <div class="bolo-bottom-holder">
                        <div class="bolo-report-id">ID: ${value.id}</div>
                        <div class="bolo-report-time-ago">${value.author
          } - ${timeAgo(Number(value.time))}</div>
                    </div>
                </div>`
        );
      });
    } else if (eventData.type == "boloComplete") {
      let id = eventData.data;
      if (canRefreshBolo == true) {
        canRefreshBolo = false;
        $(".bolos-search-refresh").empty();
        $(".bolos-search-refresh").prepend(
          `<span class="fas fa-spinner fa-spin"></span>`
        );
        setTimeout(() => {
          $(".bolos-search-refresh").empty();
          $(".bolos-search-refresh").html("Refresh");
          canRefreshBolo = true;
          $.post(`https://${GetParentResourceName()}/getAllBolos`, JSON.stringify({}));
        }, 1500);
      }
      $(".manage-bolos-editing-title").html(
        "You are currently editing BOLO " + id
      );
      $(".manage-bolos-editing-title").data("id", Number(id));
    } else if (eventData.type == "reportComplete") {
      let id = eventData.data;
      if (canRefreshReports == true) {
        canRefreshReports = false;
        $(".reports-search-refresh").empty();
        $(".reports-search-refresh").prepend(
          `<span class="fas fa-spinner fa-spin"></span>`
        );
        setTimeout(() => {
          $(".reports-search-refresh").empty();
          $(".reports-search-refresh").html("Refresh");
          canRefreshReports = true;
          $.post(`https://${GetParentResourceName()}/getAllReports`, JSON.stringify({}));
        }, 1500);
      }
      $(".manage-reports-editing-title").html(
        "You are currently editing report " + id
      );
      $(".manage-reports-editing-title").data("id", Number(id));
    } else if (eventData.type == "reports") {
      let table = eventData.data;
      canSearchForReports = true;
      $(".reports-items").empty();
      $.each(table, function (index, value) {
        $(".reports-items").append(
          `<div class="reports-item" data-id="${value.id}">
                    <div class="reports-top-holder">
                        <div class="reports-item-title">${value.title}</div>
                        <div class="reports-report-name">${value.type
          } Report</div>
                    </div>
                    <div class="reports-bottom-holder">
                        <div class="reports-report-id">ID: ${value.id}</div>
                        <div class="reports-report-time-ago">${value.author
          } - ${timeAgo(Number(value.time))}</div>
                    </div>
                </div>`
        );
      });
      $(".contextmenu").on("click", ".reports-delete", function () {
        $(".reports-items")
          .find(`[data-id="${$(this).data("info")}"]`)
          .remove();
        $.post(
          `https://${GetParentResourceName()}/deleteReports`,
          JSON.stringify({
            id: $(this).data("info"),
          })
        );
      });

      $(".reports-items").on("contextmenu", ".reports-item", function (e) {
        var args = "";
        args = [
          {
            className: "reports-delete",
            icon: "fas fa-times",
            text: "Delete Report",
            info: $(this).data("id"),
            status: "",
          },
        ];
        openContextMenu(e, args);
      });
    } else if (eventData.type == "reportData") {
      let table = eventData.data;

      $(".manage-reports-editing-title").html(
        "You are currently editing report " + table["id"]
      );

      $(".manage-reports-editing-title").data("id", Number(table["id"]));

      $(".manage-reports-input-title").val(table["title"]);
      $(".manage-reports-input-type").val(table["type"]);
      $(".manage-reports-reports-content").trumbowyg({
        changeActiveDropdownIcon: true,
        imageWidthModalEdit: true,
        btns: [
          ['foreColor', 'backColor','fontfamily','fontsize','indent', 'outdent'],
          ['strong', 'em',], ['insertImage'],
          ['viewHTML'],
          ['undo', 'redo'],
          ['formatting'],
          ['superscript', 'subscript'],
          ['link'],
          ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
          ['horizontalRule']
        ],
      });
      $(".manage-reports-reports-content").trumbowyg('html', table["details"]);

      $(".manage-reports-tags-holder").empty();
      $.each(table["tags"], function (index, value) {
        $(".manage-reports-tags-holder").append(
          `<div class="tag">${value}</div>`
        );
      });

      $(".reports-gallery-inner-container").empty();
      $.each(table["gallery"], function (index, value) {
        let randomNum = Math.ceil(Math.random() * 10).toString();
        $(".reports-gallery-inner-container").append(
          `<img src="${value}" class="reports-img ${randomNum}" onerror="this.src='img/not-found.webp'">`
        );
      });

      $(".reports-officers-tags-holder").empty();
      $.each(table["officersinvolved"], function (index, value) {
        $(".reports-officers-tags-holder").append(
          `<div class="tag">${value}</div>`
        );
      });

      $(".reports-civilians-tags-holder").empty();
      $.each(table["civsinvolved"], function (index, value) {
        $(".reports-civilians-tags-holder").append(
          `<div class="tag">${value}</div>`
        );
      });

    } else if (eventData.type == "searchedVehicles") {

    } else if (eventData.type == "getVehicleData") {
      impoundChanged = false;
      let table = eventData.data;

      $(".vehicle-information-title-holder").data(
        "dbid",
        Number(table["dbid"])
      );

      $(".vehicle-info-plate-input").val(table["plate"]);
      $(".vehicle-info-owner-input").val(table["name"]);
      $(".vehicle-info-class-input").val(table["class"]);
      $(".vehicle-info-model-input").val(table["model"]);
      $(".vehicle-info-imageurl-input").val(table["image"]);
      let vehiclePoints = table["points"] != null ? table["points"] : 0;
      $("#vehiclePointsSlider").val(vehiclePoints);
      $("#vehiclePointsSliderValue").html(vehiclePoints);

      $(".vehicle-info-content").val(table["information"]);

      $(".vehicle-tags").empty();
      $(".vehicle-info-image").attr("src", table["image"]);
      $(".vehicle-tags").prepend(
        `<div class="dmv-tag ${table.color}-color">${table.colorName}</div>`
      );

      let impound = "red-tag";
      let bolo = "red-tag";
      let codefive = "red-tag";
      let stolen = "red-tag";

      if (table.impound) {
        impound = "green-tag";
      }

      if (table.bolo) {
        bolo = "green-tag";
      }

      if (table.code) {
        codefive = "green-tag";
      }

      if (table.stolen) {
        stolen = "green-tag";
      }

      $(".vehicle-tags").append(`<div class="vehicle-tag ${impound} impound-tag">Impound</div>`);
      $(".vehicle-tags").append(`<div class="vehicle-tag ${bolo}">BOLO</div>`);
      $(".vehicle-tags").append(`<div class="vehicle-tag ${codefive} code5-tag">Code 5</div>`);
      $(".vehicle-tags").append(`<div class="vehicle-tag ${stolen} stolen-tag">Stolen</div>`);
      $(".vehicle-info-imageurl-input").val(table["image"]);
    } else if (eventData.type == "getWeaponData") {
      impoundChanged = false;
      let table = eventData.data;

      $(".weapon-information-title-holder").data( "dbid", table["id"] );

      $(".weapon-info-serial-input").val(table["serial"]);
      $(".weapon-info-owner-input").val(table["owner"]);
      $(".weapon-info-class-input").val(table["weapClass"]);
      $(".weapon-info-model-input").val(table["weapModel"]);
      $(".weapon-info-imageurl-input").val(table["image"]);

      $(".weapon-info-content").val(table["information"]);

      $(".weapon-info-image").attr("src", table["image"]);

      $(".weapon-info-imageurl-input").val(table["image"]);
      $(".contextmenu").on("click", ".weapons-delete", function () {
        $(".weapons-items")
          .find(`[data-id="${$(this).data("info")}"]`)
          .remove();
        $.post(
          `https://${GetParentResourceName()}/deleteWeapons`,
          JSON.stringify({
            id: $(this).data("info"),
          })
        );
      });

      $(".weapons-items").on("contextmenu", ".weapons-item", function (e) {
        var args = "";
        args = [
          {
            className: "weapons-delete",
            icon: "fas fa-times",
            text: "Delete Weapon Info",
            info: $(this).data("id"),
            status: "",
          },
        ];
        openContextMenu(e, args);
      });
    } else if (eventData.type == "updateVehicleDbId") {
      $(".vehicle-information-title-holder").data("dbid", Number(eventData.data));
    } else if (eventData.type == "updateIncidentDbId") {
      $(".manage-incidents-editing-title").data("id", Number(eventData.data));

      $(".manage-incidents-tags-add-btn").css("pointer-events", "auto");
      $(".manage-incidents-reports-content").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-officers-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-civilians-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".manage-incidents-evidence-add-btn").css(
        "pointer-events",
        "auto"
      );
      $(".associated-incidents-tags-add-btn").css(
        "pointer-events",
        "auto"
      );

    } else if (eventData.type == "callDetach") {
      $(".active-calls-item")
        .filter("[data-id='" + eventData.callid + "']")
        .children()
        .children()
        .find(".call-radio")
        .html(eventData.data);
    } else if (eventData.type == "callAttach") {
      $(".active-calls-item")
        .filter("[data-id='" + eventData.callid + "']")
        .children()
        .children()
        .find(".call-radio")
        .html(eventData.data);
    } else if (eventData.type == "getAllLogs") {
      let table = eventData.data;
      $(".stafflogs-box").empty();
      $.each(table, function (index, value) {
        $(".stafflogs-box").append(
          `<p style="margin : 0; padding-top:0.8vh;">► ${value.text
          } <span style="color: grey; float: right; padding-right: 1vh;">(${timeAgo(
            Number(value.time)
          )})</span></p>`
        );
      });
    } else if (eventData.type == "statusImpound") {
      const table = eventData.data;
      const plate = eventData.plate;
      const linkedreport = table["linkedreport"];
      const fee = table["fee"];
      const time = table["time"] * 1000;

      let localDate = new Date(time);
      const impoundDate = localDate.toLocaleDateString("en-US", {
        timeZone: "UTC",
      });
      const impoundTime = localDate.toLocaleTimeString("en-US", {
        timeZone: "UTC",
      });

      $(".impound-plate").val(plate).attr("disabled", "disabled");
      $(".impound-linkedreport")
        .val(linkedreport)
        .attr("disabled", "disabled");
      $(".impound-fee")
        .val("$" + fee)
        .attr("disabled", "disabled");

      if (table.paid === 1) {
        $(".impound-fee").css("color", "green");
      } else {
        $(".impound-fee").css("color", "red");
      }

      $(".impound-time")
        .val(impoundDate + "  -  " + impoundTime)
        .attr("disabled", "disabled");
      $(".impound-cancel").html("Close");
      $(".impound-submit").fadeOut(250);
      $(".impound-form").slideDown(250);
      $(".impound-form").fadeIn(250);
    } else if (eventData.type == "greenImpound") {
      $(".vehicle-tags")
        .find(".impound-tag")
        .addClass("green-tag")
        .removeClass("red-tag");
    } else if (eventData.type == "redImpound") {
      $(".vehicle-tags")
        .find(".impound-tag")
        .removeClass("green-tag")
        .addClass("red-tag");
    }
  });
});

function fidgetSpinner(page) {
  $(".close-all").fadeOut(0);
  $(".container-load").fadeIn(0);
  if (page == ".dashboard-page-container"){
    $.post(`https://${GetParentResourceName()}/getAllDashboardData`, JSON.stringify({}));
  }
  if (page == ".bolos-page-container") {
    $.post(`https://${GetParentResourceName()}/getAllBolos`, JSON.stringify({}));
  }
  if (page == ".reports-page-container") {
    $.post(`https://${GetParentResourceName()}/getAllReports`, JSON.stringify({}));
  }
  if (page == ".stafflogs-page-container") {
    $.post(`https://${GetParentResourceName()}/getAllLogs`, JSON.stringify({}));
  }
  if (page == ".incidents-page-container") {
    $.post(`https://${GetParentResourceName()}/getAllIncidents`, JSON.stringify({}));
  }
  setTimeout(() => {
    $(".container-load").fadeOut(0);
    $(page).fadeIn(0);
  }, 1250);
}

function timeShit() {
  let localDate = new Date();
  const myTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
  date = localDate.toLocaleDateString("en-US", {
    timeZone: myTimeZone,
  });
  time = localDate.toLocaleTimeString("en-US", {
    timeZone: myTimeZone,
  });
  $(".date").html(date);
  $(".time").html(time);
}

setInterval(timeShit, 1000);

function addTag(tagInput) {
  $(".tags-holder").prepend(`<div class="tag">${tagInput}</div>`);

  $.post(
    `https://${GetParentResourceName()}/newTag`,
    JSON.stringify({
      id: $(".manage-profile-citizenid-input").val(),
      tag: tagInput,
    })
  );
}

// Use the customSentence if defined, otherwise use the recommendedSentence
// This uses the assumption that customSentence will be 0 if not defined
function sendToJail(citizenId, customSentence, recommendedSentence) {
  const sentence = Number(customSentence) || Number(recommendedSentence);

  $.post(`https://${GetParentResourceName()}/sendToJail`, JSON.stringify({
    citizenId,
    sentence,
  }));
}

// Use the customSentence if defined, otherwise use the recommendedSentence
// This uses the assumption that customSentence will be 0 if not defined
function sendToCommunityService(citizenId, customSentence, recommendedSentence) {
  const sentence = Number(customSentence) || Number(recommendedSentence);

  $.post(`https://${GetParentResourceName()}/sendToCommunityService`, JSON.stringify({
    citizenId,
    sentence,
  }));
}

// Use the customFine if defined, otherwise use the recommendedFine
// This uses the assumption that customFine will be 0 if not defined
function sendFine(citizenId, customFine, recommendedFine, incidentId) {
  const fine = Number(customFine) || Number(recommendedFine);

  $.post(`https://${GetParentResourceName()}/sendFine`, JSON.stringify({
    citizenId,
    fine,
    incidentId,
  }));
}
// Context menu

var menu = document.querySelector(".contextmenu");

function showMenu(x, y) {
  $(".contextmenu").css("left", x + "px");
  $(".contextmenu").css("top", y + "px");
  $(".contextmenu").addClass("contextmenu-show");
}

function showChargesMenu(x, y) {
  $(".ccontextmenu").css("left", x + "px");
  $(".ccontextmenu").css("top", y + "px");
  $(".ccontextmenu").addClass("ccontextmenu-show");
}

function hideMenu() {
  $(".contextmenu").removeClass("contextmenu-show");
}

function hideChargesMenu() {
  $(".ccontextmenu").removeClass("ccontextmenu-show");
}

function onMouseDown(e) {
  hideMenu();
  hideChargesMenu();
  document.removeEventListener("mouseup", onMouseDown);
}

function openContextMenu(e, args) {
  e.preventDefault();
  showMenu(e.pageX, e.pageY);
  $(".contextmenu").empty();
  $.each(args, function (index, value) {
    if (value.status !== "blur(5px)") {
      $(".contextmenu").prepend(
        `
                <li class="contextmenu-item ${value.className}" data-info="${value.info}" data-status="${value.status}">
                    <a href="#" class="contextmenu-btn">
                        <i class="${value.icon}"></i>
                        <span class="contextmenu-text">${value.text}</span>
                    </a>
                </li>
                `
      );
    }
  });
  document.addEventListener("mouseup", onMouseDown);
}

function openChargesContextMenu(e, args) {
  e.preventDefault();
  showChargesMenu(e.pageX, e.pageY);
  $(".ccontextmenu").empty();
  $.each(args, function (index, value) {
    if (value.status !== "blur(5px)") {
      $(".ccontextmenu").prepend(
        `
        <li class="ccontextmenu-item ${value.className}" data-info="${value.info}" data-status="${value.status}">
            <span class="ccontextmenu-text">${value.info}</span>
        </li>
        `
      );
    }
  });
  document.addEventListener("mouseup", onMouseDown);
}

function expandImage(url) {
  $(".close-all").css("filter", "brightness(35%)");
  $(".gallery-image-enlarged").fadeIn(150);
  $(".gallery-image-enlarged").css("display", "block");
  $(".gallery-image-enlarged").attr("src", url);
}

function copyImageSource(url) {
  const el = document.createElement('textarea');
  el.value = url;
  document.body.appendChild(el);
  el.select();
  document.execCommand('copy');
  document.body.removeChild(el);
}

function removeImage(url) {
  let cid = $(".manage-profile-citizenid-input").val();
  $(".gallery-inner-container img")
    .filter("[src='" + url + "']")
    .remove();
}

function hideIncidentsMenu() {
  if (
    $(".incidents-person-search-container").css("display") != "none" &&
    !mouse_is_inside
  ) {
    $(".incidents-person-search-container").fadeOut(250);
    $(".close-all").css("filter", "none");
  }
  if (
    $(".convictions-known-container").css("display") != "none" &&
    !mouse_is_inside
  ) {
    $(".convictions-known-container").fadeOut(0);
    $(".close-all").css("filter", "none");
  }
  if (
    $(".incidents-known-container").css("display") != "none" &&
    !mouse_is_inside
  ) {
    $(".incidents-known-container").fadeOut(0);
    $(".close-all").css("filter", "none");
  }
}

function onMouseDownIncidents(e) {
  hideIncidentsMenu();
  document.removeEventListener("mouseup", onMouseDownIncidents);
}

function titleCase(str) {
  return str
    .split(' ')
    .map((word) => word[0].toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

function searchProfilesResults(result) {
  canSearchForProfiles = true;
  $(".profile-items").empty();

  if (result.length < 1) {
    $(".profile-items").html(
      `
                      <div class="profile-item" data-id="0">

                          <div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 5px; width: 100%; padding: 5px;">
                          <div style="display: flex; flex-direction: column;">
                              <div class="profile-item-title">No Users Matching that search</div>
                              </div>
                              <div class="profile-bottom-info">
                              </div>
                          </div>
                      </div>
              `
    );
    return true;
  }

  let profileHTML = "";

  result.forEach((value) => {
    let charinfo = value.charinfo;
    let metadata = value.metadata;

    if (typeof value.charinfo == "string") {
      charinfo = JSON.parse(charinfo);
    }

    if (typeof value.metadata == "string") {
      metadata = JSON.parse(metadata);
    }

    if (!metadata) {
      metadata = {};
    }

    if (!metadata.licences) {
      metadata.licences = {};
    }

    let name = charinfo.firstname + " " + charinfo.lastname;
    let warrant = "red-tag";
    let convictions = "red-tag";

    let licences = "";
    let licArr = Object.entries(value.licences);

    if (licArr.length == 0 || licArr.length == undefined) {
      var licenseTypes = licenseTypesGlobal;
      licArr = Object.entries(licenseTypes.reduce((licenseType, licenseValue) => (licenseType[licenseValue] = false, licenseType), {}));
    }

    if (licArr.length > 0 && (PoliceJobs[playerJob] !== undefined || DojJobs[playerJob] !== undefined)) {
      for (const [lic, hasLic] of licArr) {
        let tagColour =
          hasLic == true ? "green-tag" : "red-tag";
        licences += `<span class="license-tag ${tagColour}">${titleCase(lic)}</span>`;
      }
    }

    if (value.warrant == true) {
      warrant = "green-tag";
    }

    if (value.convictions < 5) {
      convictions = "green-tag";
    } else if (
      value.convictions > 4 &&
      value.convictions < 15
    ) {
      convictions = "orange-tag";
    }

    if (value.pp == '') {
      value.pp = 'img/not-found.webp'
    }

    profileHTML += `
    <div class="profile-item" data-id="${value.citizenid}" data-fingerprint="${value.fingerprint}">
        <img src="${value.pp}" class="profile-image">
        <div style="display: flex; flex-direction: column; margin-top: 2.5px; margin-left: 5px; width: 100%; padding: 5px;">
        <div style="display: flex; flex-direction: column;">
            <div class="profile-item-title">${name}</div>
            <div class="profile-tags">
                ${licences}
            </div>
            <div class="profile-criminal-tags">
                <span class="license-tag ${warrant}">${value.warrant ? "Active" : "No"} Warrant</span>
                <span class="license-tag ${convictions}">${value.convictions} Convictions </span>
            </div>
        </div>
        <div class="profile-bottom-info">
            <div class="profile-id"><span class="fas fa-id-card"></span> Citizen ID: ${value.citizenid}</div>&nbsp;
        </div>
        </div>
    </div>
`;
  });

  $(".profile-items").html(profileHTML);
}

window.addEventListener("message", (event) => {
  if (event.data.action === "updateOfficerData") {
    updateOfficerData(event.data.data);
  } else if (event.data.action === "updateFingerprintData") {
    const { fingerprint } = event.data;
    if (fingerprint && fingerprint !== "") {
      $(".manage-profile-fingerprint-input").val(fingerprint);
    } else {
      $(".manage-profile-fingerprint-input").val("");
    }
  }
});

function updateOfficerData(officerData) {
  // Convert totalTime to totalSeconds for sorting
  officerData.forEach(officer => {
    officer.totalSeconds = timeStringToSeconds(officer.totalTime);
  });

  // Sort based on totalSeconds
  officerData.sort((a, b) => b.totalSeconds - a.totalSeconds);

  // Efficiently create officer elements
  const officerElements = officerData.map((officer, index) => {
    const position = getPosition(index + 1);
    const color = index < 3 ? 'white' : 'grey';

    return `<div class="leaderboard-box-test" style="font-size: 1.3vh; font-weight: lighter; color: ${color};">
      ► ${position}: ${officer.name} (${officer.callsign})<span style="float: right; padding-right: 1vh;">${officer.totalTime}</span>
    </div>`;
  }).join('');

  // Update the DOM once
  const leaderboardBox = document.querySelector('.leaderboard-box');
  leaderboardBox.innerHTML = officerElements;
}

function getPosition(rank) {
  const ordinal = rank % 10;
  if (rank === 11 || rank === 12 || rank === 13) {
    return rank + 'th';
  }
  return rank + (ordinal === 1 ? 'st' : ordinal === 2 ? 'nd' : ordinal === 3 ? 'rd' : 'th');
}

function timeStringToSeconds(t) {
  if (!t) return 0;

  let days = 0, hours = 0, minutes = 0, seconds = 0;
  let daysPart = '0';
  let timePart = t;

  // days vs day check
  if (t.includes(' days ')) {
    [daysPart, timePart] = t.split(' days ');
  }

  const timeParts = timePart.split(' ');

  for (let i = 0; i < timeParts.length; i += 2) {
    const val = parseInt(timeParts[i]);
    switch (timeParts[i + 1]) {
      case 'hours':
        hours = val;
        break;
      case 'minutes':
        minutes = val;
        break;
      case 'seconds':
        seconds = val;
        break;
    }
  }

  days = parseInt(daysPart);

  return (
    days * 86400 +
    hours * 3600 +
    minutes * 60 +
    seconds
  );
}


window.addEventListener("load", function () {
  document
    .getElementById("offenses-search")
    .addEventListener("keyup", function () {
      var search = this.value.toLowerCase();
      if (search.length > 1) {
        $.each($(".offense-item"), function (i, d) {
          const Name = $(this)
            .find(".offense-item-offense")
            .html()
            .toLowerCase();
          const Number = $(this)
            .find(".offense-item-id")
            .html()
            .toLowerCase();
          if (Name.includes(search)) {
            $(this).show();
          } else if (Number.includes(search)) {
            $(this).show();
          } else {
            $(this).hide();
          }
        });
      } else {
        $.each($(".offense-item"), function (i, d) {
          $(this).show();
        });
      }
    });
});


          // Dispatch Map //
customcrs = L.extend({}, L.CRS.Simple, {
  projection: L.Projection.LonLat,
  scale: function(zoom) {

      return Math.pow(2, zoom);
  },
  zoom: function(sc) {

      return Math.log(sc) / 0.6931471805599453;
  },
  distance: function(pos1, pos2) {
      var x_difference = pos2.lng - pos1.lng;
      var y_difference = pos2.lat - pos1.lat;
      return Math.sqrt(x_difference * x_difference + y_difference * y_difference);
  },
  transformation: new L.Transformation(0.02072, 117.3, -0.0205, 172.8),
  infinite: false
});

var map = L.map("map-item", {
crs: customcrs,
minZoom: 3,
maxZoom: 5,
zoom: 5,

noWrap: true,
continuousWorld: false,
preferCanvas: true,

center: [0, -1024],
maxBoundsViscosity: 1.0
});
 // https://upload.versescripts.net/ 
var customImageUrl = 'https://files.fivemerr.com/images/60c68fc9-1a7f-4e5a-800a-f760a74186ca.jpeg';

var sw = map.unproject([0, 1024], 3 - 1);
var ne = map.unproject([1024, 0], 3 - 1);
var mapbounds = new L.LatLngBounds(sw, ne);
map.setView([-300, -1500], 4);
map.setMaxBounds(mapbounds);


map.attributionControl.setPrefix(false)

L.imageOverlay(customImageUrl, mapbounds).addTo(map);

map.on('dragend', function() {
  if (!mapbounds.contains(map.getCenter())) {
      map.panTo(mapbounds.getCenter(), { animate: false });
  }
});

var Dispatches = {};
var DispatchPing = L.divIcon({
  html: '<i class="fa fa-location-dot fa-2x"></i>',
  iconSize: [20, 20],
  className: 'map-icon map-icon-ping',
  offset: [-10, 0]
});
var mapMarkers = L.layerGroup();

function DispatchMAP(DISPATCH) {
  var MIN = Math.round(Math.round((new Date() - new Date(DISPATCH.time)) / 1000) / 60);
  if (MIN > 10) return;

  var COORDS_X = DISPATCH.coords.x
  var COORDS_Y = DISPATCH.coords.y
  var CODE = DISPATCH.id

  Dispatches[CODE] = L.marker([COORDS_Y, COORDS_X], { icon: DispatchPing });
  Dispatches[CODE].addTo(map);

  // Automatic deletion after a period of 20 minutes, equivalent to 1200000 milliseconds.
  setTimeout(function() {
    map.removeLayer(Dispatches[CODE]);
  }, 1200000);

  Dispatches[CODE].bindTooltip(`<div class="map-tooltip-info">${DISPATCH.message}</div></div><div class="map-tooltip-id">#${DISPATCH.id}</div>`,
      {
          direction: 'top',
          permanent: false,
          offset: [0, -10],
          opacity: 1,
          interactive: true,
          className: 'map-tooltip'
  });

  Dispatches[CODE].addTo(mapMarkers);

  Dispatches[CODE].on('click', function() {
      const callId = CODE
      $.post(
          `https://${GetParentResourceName()}/setWaypoint`,
          JSON.stringify({
              callid: callId,
          })
      );
  });

  Dispatches[CODE].on('contextmenu', function() {
      map.removeLayer(Dispatches[CODE]);
  });

}

function ClearMap() {
$(".leaflet-popup-pane").empty();
$(".leaflet-marker-pane").empty();
}

$(".map-clear").on('click', function() {
    $(".map-clear").empty();
    $(".map-clear").prepend(
      `<span class="fas fa-spinner fa-spin"></span>`
    );
    setTimeout(() => {
      $(".map-clear").empty();
      $(".map-clear").html("Clear");
      ClearMap();
    }, 1500);
});
