/* 
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */


function AllSubjects()
{
    for(var x=0;x<document.form.elements.length;x++) {
        var y=document.form.elements[x];
        if ((y.name!='chooseAll') && (y.name!='post[venue]')) {
            y.checked=document.form.chooseAll.checked;
        }
    }
}