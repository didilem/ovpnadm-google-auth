var activeEdit = '';

function clearDate (id) {
  var field = $('#' + id);
  field.val('');
}

function uploadForm(form,callBack,to)
{
   if (!to) to = 'dataContainer';
   console.log(to + ':' + callBack);
   var data = new FormData(form);
    $.ajax({
        url: 'index.pl',
        type: 'POST',
        dataType: "html",
        data: data,
        cache: false,
        processData: false,
        contentType: false,
        success: function(html){
            window[callBack].call(null,html,to);
        }        
    });
}

function revokeClientConfirmed (idEl,id) {
  var form = document.getElementById(idEl);
  form.action.value = 'revoke';
  form.confirmed.value = '1';
  uploadForm(form,'showAddNet','editNetwork_' + id);
}

function revokeClient (idEl,id) {
  var form = document.getElementById(idEl);
  form.action.value = 'revoke';
  uploadForm(form,'showAddNet','exportClient_' + id);
  var exportPanel = $('#' + 'exportClient_' + id);
  exportPanel.fadeIn(200);
  activeEdit = '';
}

function exportClient (idEl,id) {
  var form = document.getElementById(idEl);
  form.action.value = 'export';
  uploadForm(form,'showAddNet','exportClient_' + id);
  var exportPanel = $('#' + 'exportClient_' + id);
  exportPanel.fadeIn(200);
  form.action.value = 'clients';
}

function addNet (me) {
   var form = $('form');
   uploadForm(form[0],'showAddNet','dataContainer');
}

function showAddNet(myhtml,to) {
   if (!to) to = 'dataContainer';
   var mainContent = $('#' + to);
   mainContent.html(myhtml);
}

function updateListEdit (id,target) {
   var form = document.getElementById(id);
   uploadForm(form,'showAddNet',target);
   activeEdit = '';
}

function confirmDelete (id,target) {
   var form = document.getElementById(id);
   form.confirmed.value = 1;
   form.netName.value = '';
   uploadForm(form,'showAddNet',target);
   activeEdit = '';
}

function confirmDeleteGrp (id,target) {
   var form = document.getElementById(id);
   form.confirmed.value = 1;
   form.grpName.value = '';
   uploadForm(form,'showAddNet',target);
   activeEdit = '';
}

function cancelDelete (id,target) {
   var form = document.getElementById(id);
   form.confirmed.value = 0;
   uploadForm(form,'showAddNet',target);
}

function cancelRevoke (id,target) {
  var form = document.getElementById(id);
  form.confirmed.value = 0;
  form.action.value = 'clients';
  var exportPanel = $('#' + target);
  uploadForm(form,'showAddNet',target);
  activeEdit = '';
}

function showListEdit(id,panel) {
  var editPanel = $('#' + panel + '_' + id);
  if (activeEdit && id != activeEdit) {
    var editPanelOld = $('#' + panel + '_' + activeEdit);
    editPanelOld.fadeOut(200, function() {
        activeEdit = '';
        showListEdit(id,panel);
    } ); 
  } else if (activeEdit && id == activeEdit) {
    editPanel.fadeOut(200);
    activeEdit = '';
  } else {
    activeEdit = id;
    editPanel.fadeIn(200);
  }
}
