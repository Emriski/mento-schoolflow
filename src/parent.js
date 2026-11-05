import { createClient } from "@supabase/supabase-js";

const db=createClient('https://rkwcfkkckfitcgvstekr.supabase.co','sb_publishable_eFBNcaDH6ZtRBo2lIRORug_BDmCDFyC');
const $=id=>document.getElementById(id);let user=null,children=[],results=[],fees=[],feeSchedules=[],attendance=[],schoolId=null,activeConversation=null,chatChannel=null,chatMode='parent_teacher',chatRecipients=[],pendingChatMessageId=null;
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=v=>'₦'+Number(v||0).toLocaleString('en-NG');
function message(t,type=''){ $('message').textContent=t;$('message').className='message '+type;$('message').classList.remove('hidden');}
function showApp(on){$('auth').classList.toggle('hidden',on);$('dashboard').classList.toggle('hidden',!on);$('signOut').classList.toggle('hidden',!on);}
async function loadAccount(){
 user=(await db.auth.getUser()).data.user;if(!user){showApp(false);return}showApp(false);
 // Staff accounts must use the staff portal, even if a guardian link exists.
 const staffProfile=await db.from('profiles').select('id,role').eq('id',user.id).maybeSingle();
 if(staffProfile.error)throw staffProfile.error;
 if(staffProfile.data){await db.auth.signOut();user=null;showApp(false);message('This account is registered as '+staffProfile.data.role.replace('_',' ')+'. Please sign in through the Staff Portal.','error');return}
 // Parent access requires an explicit guardian link for this authenticated account.
 const g=await db.from('student_guardians').select('student_id,school_id,guardian_name').eq('guardian_user_id',user.id);
 if(g.error)throw g.error;
 showApp(true);
 const ids=[...new Set((g.data||[]).map(x=>x.student_id))];schoolId=g.data?.[0]?.school_id||null;
 if(!ids.length){children=[];results=[];fees=[];attendance=[];render();message('No children are linked to this account yet. Please ask the school administrator or head teacher to verify and link your parent account to your guardian record.','');return}
 const [s,r,f,a]=await Promise.all([
  db.from('students').select('id,full_name,student_code,class_id,school_id,active').in('id',ids).eq('active',true),
  db.from('student_results').select('id,student_id,academic_year,term,subject,ca_score,ca_max,exam_score,exam_max,total_score,total_max,percentage,grade,remarks,created_at').in('student_id',ids).order('created_at',{ascending:false}),
  db.from('school_fee_records').select('id,student_id,academic_year,term,amount_due,amount_paid,payment_status,updated_at').in('student_id',ids).order('updated_at',{ascending:false}),
  db.from('attendance_records').select('id,student_id,status,marked_at,session_id').in('student_id',ids).order('marked_at',{ascending:false})
 ]);
 for(const x of [s,r,f,a])if(x.error)throw x.error;
 children=s.data||[];results=r.data||[];fees=f.data||[];attendance=a.data||[];
 const classIds=[...new Set(children.map(x=>x.class_id).filter(Boolean))];
 feeSchedules=[];
 if(classIds.length){
  const fs=await db.from('school_fee_schedules').select('id,class_id,academic_year,term,items,total_due').in('class_id',classIds).eq('school_id',schoolId).eq('is_published',true).order('academic_year',{ascending:false});
  if(!fs.error)feeSchedules=fs.data||[];
 }
 const sessionIds=[...new Set(attendance.map(x=>x.session_id).filter(Boolean))];
 if(sessionIds.length){const ss=await db.from('attendance_sessions').select('id,attendance_date,class_id').in('id',sessionIds);if(ss.error)throw ss.error;const map=new Map((ss.data||[]).map(x=>[x.id,x]));attendance=attendance.map(x=>({...x,session:map.get(x.session_id)}));}
 render();
 await loadConversations();
}

let parentLoadPromise=null;
function load(){if(parentLoadPromise)return parentLoadPromise;parentLoadPromise=loadAccount().catch(async e=>{showApp(false);await db.auth.signOut();throw e}).finally(()=>{parentLoadPromise=null});return parentLoadPromise}
function chatStatus(t){$('chatStatus').textContent=t||''}
function closeChatChannel(){if(chatChannel){db.removeChannel(chatChannel);chatChannel=null}}
async function loadConversations(){
 const {data,error}=await db.from('school_conversations').select('id,subject,conversation_type,student_id,updated_at').order('updated_at',{ascending:false});
 if(error)throw error;
 const rows=data||[];
 $('conversationList').innerHTML=rows.length?rows.map(x=>'<button type="button" class="chat-item '+(x.id===activeConversation?'active':'')+'" data-conversation="'+esc(x.id)+'"><strong>'+esc(x.subject)+'</strong><br><small>'+esc(x.conversation_type.replace('_',' '))+'</small></button>').join(''):'<p class="notice">No conversations yet.</p>';
}
async function startNewChat(type){
 chatMode=type;$('newConversation').classList.remove('hidden');$('chatActive').classList.add('hidden');
 $('chatStudent').innerHTML=children.map(x=>'<option value="'+esc(x.id)+'">'+esc(x.full_name)+'</option>').join('');
 $('chatRecipient').innerHTML='<option value="">Loading recipients…</option>';
 const table=type==='parent_teacher'?'teacher':'admin';
 const {data,error}=await db.rpc('schoolflow_parent_message_recipients',{p_role:table});
 if(error)throw error;
 chatRecipients=data||[];
 $('chatRecipient').innerHTML=chatRecipients.map(x=>'<option value="'+esc(x.id)+'">'+esc(x.full_name)+'</option>').join('')||'<option value="">No '+(table==='teacher'?'teachers':'administrators')+' available</option>';
}
async function createChat(){
 const studentId=$('chatStudent').value,recipient=$('chatRecipient').value,subject=$('chatSubject').value.trim();
 if(!studentId||!recipient||!subject)throw new Error('Choose your child, recipient and enter a subject.');
 const {data,error}=await db.rpc('schoolflow_create_conversation',{p_type:chatMode,p_student_id:studentId,p_recipient_user_id:recipient,p_subject:subject});
 if(error)throw error;
 $('newConversation').classList.add('hidden');$('chatActive').classList.remove('hidden');$('chatSubject').value='';
 await loadConversations();await openConversation(data);
}
async function openConversation(id){
 activeConversation=id;pendingChatMessageId=null;closeChatChannel();
 const {data:conv,error}=await db.from('school_conversations').select('id,subject,conversation_type').eq('id',id).single();
 if(error)throw error;
 $('chatTitle').textContent=conv.subject;$('chatBody').disabled=false;$('sendChatMessage').disabled=false;
 await renderChatMessages();
 chatChannel=db.channel('parent-chat-'+id).on('postgres_changes',{event:'INSERT',schema:'public',table:'school_messages',filter:'conversation_id=eq.'+id},()=>renderChatMessages().catch(e=>chatStatus(e.message))).subscribe();
 await loadConversations();
}
async function renderChatMessages(){
 if(!activeConversation)return;
 const {data,error}=await db.from('school_messages').select('id,sender_id,body,created_at').eq('conversation_id',activeConversation).order('created_at',{ascending:true}).limit(200);
 if(error)throw error;
 $('chatMessages').innerHTML=(data||[]).map(x=>'<div class="bubble '+(x.sender_id===user.id?'mine':'')+'"><div>'+esc(x.body).replace(/\n/g,'<br>')+'</div><small>'+esc(new Date(x.created_at).toLocaleString())+(x.sender_id===user.id?' · You':'')+'</small></div>').join('')||'<p class="muted">No messages yet. Send the first message.</p>';
 $('chatMessages').scrollTop=$('chatMessages').scrollHeight;
}
async function sendChat(){
 const body=$('chatBody').value.trim();if(!body||!activeConversation)return;
 const b=$('sendChatMessage');b.disabled=true;chatStatus('Sending…');
 if(!pendingChatMessageId)pendingChatMessageId=crypto.randomUUID();
 try{
  const {error}=await db.from('school_messages').insert({conversation_id:activeConversation,sender_id:user.id,client_message_id:pendingChatMessageId,body});
  if(error)throw error;
  $('chatBody').value='';pendingChatMessageId=null;chatStatus('Sent');await renderChatMessages();
 }catch(e){chatStatus('Message not sent: '+e.message+'. Your text is still here—tap Send to retry.')}
 finally{b.disabled=false}
}
$('newTeacherChat').addEventListener('click',()=>startNewChat('parent_teacher').catch(e=>chatStatus(e.message)));
$('newAdminChat').addEventListener('click',()=>startNewChat('parent_admin').catch(e=>chatStatus(e.message)));
$('createConversation').addEventListener('click',()=>createChat().catch(e=>chatStatus(e.message)));
$('cancelConversation').addEventListener('click',()=>{$('newConversation').classList.add('hidden');$('chatActive').classList.remove('hidden')});
$('sendChatMessage').addEventListener('click',()=>sendChat());
$('chatBody').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendChat()}});
$('conversationList').addEventListener('click',e=>{const b=e.target.closest('[data-conversation]');if(b)openConversation(b.dataset.conversation).catch(x=>chatStatus(x.message))});

function childName(id){return children.find(c=>c.id===id)?.full_name||'Student'}
function render(){
 $('welcome').textContent='Welcome'+(user?.email?'':'')+', parent';$('childCount').textContent=children.length;$('resultCount').textContent=results.length;$('balance').textContent=money(fees.reduce((n,x)=>n+Math.max(0,Number(x.amount_due||0)-Number(x.amount_paid||0)),0));
 $('children').innerHTML=children.length?children.map(c=>'<div class="student"><h3>'+esc(c.full_name)+'</h3><div class="muted">Student ID: '+esc(c.student_code||'Not assigned')+'</div></div>').join(''):'<p>No linked children found.</p>';
 $('results').innerHTML='<h2>Academic results</h2>'+(results.length?'<div class="tablewrap"><table><thead><tr><th>Student</th><th>Year / Term</th><th>Subject</th><th>Score</th><th>Grade</th><th>Remarks</th></tr></thead><tbody>'+results.map(x=>'<tr><td>'+esc(childName(x.student_id))+'</td><td>'+esc(x.academic_year)+' / '+esc(x.term)+'</td><td>'+esc(x.subject)+'</td><td>'+esc(x.total_score)+' / '+esc(x.total_max)+' ('+esc(x.percentage)+'%)</td><td>'+esc(x.grade)+'</td><td>'+esc(x.remarks||'—')+'</td></tr>').join('')+'</tbody></table></div>':'<p>No results have been published for your linked children yet.</p>');
 $('attendance').innerHTML='<h2>Attendance history</h2>'+(attendance.length?'<div class="tablewrap"><table><thead><tr><th>Student</th><th>Date</th><th>Status</th></tr></thead><tbody>'+attendance.map(x=>'<tr><td>'+esc(childName(x.student_id))+'</td><td>'+esc(x.session?.attendance_date||x.marked_at||'—')+'</td><td>'+esc(x.status)+'</td></tr>').join('')+'</tbody></table></div>':'<p>No attendance records available yet.</p>');
 $('fees').innerHTML='<h2>School fees</h2>'+(feeSchedules.length?'<h3>Published class fee schedules</h3>'+feeSchedules.map(x=>{const names=children.filter(ch=>ch.class_id===x.class_id).map(ch=>esc(ch.full_name)).join(', ');const items=Array.isArray(x.items)?x.items:[];return '<div class="student"><strong>'+esc(names||'Your child')+' · '+esc(x.academic_year)+' / '+esc(x.term)+'</strong><ul>'+items.map(i=>'<li>'+esc(i.name)+': '+money(i.amount)+'</li>').join('')+'</ul><strong>Total: '+money(x.total_due)+'</strong></div>'}).join(''):'<p class="muted">No published class fee schedule is available for your linked children yet.</p>')+(fees.length?'<div class="tablewrap"><table><thead><tr><th>Student</th><th>Year / Term</th><th>Amount due</th><th>Paid</th><th>Balance</th><th>Status</th></tr></thead><tbody>'+fees.map(x=>'<tr><td>'+esc(childName(x.student_id))+'</td><td>'+esc(x.academic_year)+' / '+esc(x.term)+'</td><td>'+money(x.amount_due)+'</td><td>'+money(x.amount_paid)+'</td><td>'+money(Math.max(0,Number(x.amount_due||0)-Number(x.amount_paid||0)))+'</td><td>'+esc(x.payment_status)+'</td></tr>').join('')+'</tbody></table></div>':'<p>No fee records available yet.</p>');
}
document.querySelectorAll('[data-toggle-password]').forEach(b=>b.addEventListener('click',()=>{const input=$(b.dataset.togglePassword);if(!input)return;const reveal=input.type==='password';input.type=reveal?'text':'password';b.textContent=reveal?'Hide':'Show';b.setAttribute('aria-pressed',String(reveal))}));
$('forgotPasswordBtn').addEventListener('click',async()=>{const email=$('email').value.trim();if(!email){message('Enter your account email address first, then select Forgot password again.','error');$('email').focus();return}const b=$('forgotPasswordBtn');b.disabled=true;try{const {error}=await db.auth.resetPasswordForEmail(email,{redirectTo:'https://mento-schoolflow.vercel.app/parent.html'});if(error)throw error;message('If an account exists for '+email+', a password-reset email has been requested. Check your inbox and spam folder.','success')}catch(e){message(e.message||'Could not request a password reset. Please try again.','error')}finally{b.disabled=false}});
$('recoveryForm').addEventListener('submit',async e=>{e.preventDefault();const b=e.currentTarget.querySelector('button[type="submit"]');b.disabled=true;try{const password=$('recoveryPassword').value;if(password.length<8)throw new Error('Use at least 8 characters for your new password.');const {error}=await db.auth.updateUser({password});if(error)throw error;$('recoveryView').classList.add('hidden');$('recoveryForm').reset();message('Your password has been updated. You can now use it to sign in.','success');await load()}catch(e){message(e.message||'Could not update your password. Please reopen the reset link and try again.','error')}finally{b.disabled=false}});
$('login').addEventListener('submit',async e=>{e.preventDefault();try{const {error}=await db.auth.signInWithPassword({email:$('email').value.trim(),password:$('password').value});if(error)throw error;message('Signed in successfully.');await load()}catch(e){message(e.message||'Unable to sign in.','error')}});
$('signup').addEventListener('submit',async e=>{e.preventDefault();try{const {data,error}=await db.auth.signUp({email:$('newEmail').value.trim(),password:$('newPassword').value});if(error)throw error;if(data.session){message('Account created. Loading your dashboard.','success');await load()}else message('Account created. Check your email for a confirmation link, then sign in.','success')}catch(e){message(e.message||'Unable to create account.','error')}});
$('signOut').addEventListener('click',async()=>{await db.auth.signOut();showApp(false);message('You have signed out.')});
document.querySelectorAll('[data-tab]').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('[data-tab]').forEach(x=>x.classList.toggle('active',x===b));['children','results','attendance','fees','messages'].forEach(id=>$(id).classList.toggle('hidden',id!==b.dataset.tab))}));
db.auth.onAuthStateChange((event,session)=>{if(event==='PASSWORD_RECOVERY'){$('auth').classList.add('hidden');$('dashboard').classList.add('hidden');$('recoveryView').classList.remove('hidden');message('Choose a new password to finish recovering your account.');return}if(session)setTimeout(()=>load().catch(e=>message(e.message||'Unable to load parent data. Check database permissions.','error')),0);else showApp(false)});
try{await load()}catch(e){message(e.message||'Unable to load parent data. Database permissions may not be configured yet.','error')}
