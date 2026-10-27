/* Mento SchoolFlow dashboard components — each renderer owns one dashboard section. */
(function(){
  const $ = (id) => document.getElementById(id);
  const escText = (value) => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const initialsText = (name) => String(name || 'Student').trim().split(/\s+/).filter(Boolean).slice(0,2).map(part=>part[0]).join('').toUpperCase();
  const safeStudents = () => (typeof students !== 'undefined' && Array.isArray(students)) ? students : [];
  const safeAttendance = () => (typeof attendance !== 'undefined' && attendance) ? attendance : {};
  const totalScore = (s) => Math.max(0,Math.min(100,(Number(s.ca)||0)+(Number(s.exam)||0)));
  const selectedClass = () => $('overviewClassFilter')?.value || '';
  const filteredStudents = () => safeStudents().filter(s => !selectedClass() || s.className === selectedClass());
  const avg = (list) => list.length ? Math.round(list.reduce((sum,s)=>sum+totalScore(s),0)/list.length) : 0;

  function renderSchoolHeader(){
    return '<div class="school-header"><div class="school-identity"><div class="school-mark">S</div><div><div class="school-heading" id="overviewSchoolHeading">SchoolFlow</div><span class="school-subtitle">by Mento Solutions · School management workspace</span></div></div><div class="school-user"><div class="school-user-copy">Signed in as<strong>Administrator</strong></div><div class="school-user-avatar">AD</div></div></div>';
  }
  function renderDashboardIntro(){
    return '<div class="dashboard-intro"><div><div class="eyebrow" id="overviewDate">SCHOOL OVERVIEW</div><h1 class="h1">School at a glance</h1><p class="sub">A quick, clear view of attendance, achievement and student progress.</p></div><div class="actions"><button class="btn" onclick="showView(\'attendance\')">Take attendance</button><button class="btn primary" onclick="showView(\'teacher\')">Open Teacher Assistant</button></div></div>';
  }
  function renderDashboardFilters(){
    return '<div class="dashboard-filters"><div class="filter-control"><label for="overviewClassFilter">Class</label><select id="overviewClassFilter" onchange="renderOverview()"><option value="">All classes</option><option>Primary 5</option><option>JSS 1</option><option>JSS 2</option><option>SS 1</option><option>SS 2</option></select></div><div class="filter-control"><label for="overviewTermFilter">Term</label><select id="overviewTermFilter" onchange="renderOverview()"><option>First term</option><option>Second term</option><option>Third term</option></select></div><div class="filter-control"><label for="overviewAssessmentFilter">Assessment</label><select id="overviewAssessmentFilter" onchange="renderOverview()"><option>All assessments</option><option>Mathematics</option><option>English Language</option><option>Basic Science</option></select></div><div class="filter-control"><label for="overviewSessionFilter">Session</label><select id="overviewSessionFilter" onchange="renderOverview()"><option>2026/2027</option><option>2025/2026</option></select></div></div>';
  }
  function renderTrend(color, points){
    return '<svg class="kpi-trend" viewBox="0 0 180 24" preserveAspectRatio="none" aria-hidden="true"><path d="M0 22 '+points+' L180 22 L0 22Z" fill="'+color+'" opacity=".10"></path><polyline points="'+points+'" fill="none" stroke="'+color+'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></polyline></svg>';
  }
  function renderKpiCards(){
    const displayPresent=213,displayLate=14,displayAbsent=21,displayTotal=248,pending=18;
    return '<div class="grid dashboard-stats">'+
      '<article class="card dashboard-kpi"><div class="kpi-top">Total students <span class="kpi-icon">♙</span></div><div class="kpi-value">248</div><div class="kpi-note">12 sample records available</div>'+renderTrend('var(--indigo-600)','0,18 25,14 48,17 70,8 95,12 122,4 150,8 180,2')+'</article>'+
      '<article class="card dashboard-kpi"><div class="kpi-top">Present today <span class="kpi-icon">✓</span></div><div class="kpi-value">'+displayPresent+'</div><div class="kpi-note">'+displayTotal+' students accounted for</div>'+renderTrend('var(--teal)','0,19 22,15 45,17 68,10 92,12 118,7 144,9 180,3')+'</article>'+
      '<article class="card dashboard-kpi"><div class="kpi-top">Classes active <span class="kpi-icon">▦</span></div><div class="kpi-value">12</div><div class="kpi-note">Across primary, junior and senior sections</div>'+renderTrend('var(--purple)','0,20 22,17 45,18 68,12 92,13 118,7 144,9 180,4')+'</article>'+
      '<button class="card dashboard-kpi kpi-review" onclick="showView(\'results\')" aria-label="Review pending results"><div class="kpi-top">Results to review <span class="kpi-icon">▤</span></div><div class="kpi-value">'+pending+'</div><div class="kpi-note">Open assessment results →</div>'+renderTrend('var(--amber)','0,20 22,17 45,18 68,11 92,14 118,7 144,10 180,4')+'</button>'+
    '</div>';
  }
  function renderPerformanceBars(){
    const source=safeStudents();
    const classes=['Primary 5','JSS 1','JSS 2','SS 1','SS 2'].filter(cl=>(!selectedClass()||selectedClass()===cl)&&source.some(s=>s.className===cl));
    const groups=classes.length?classes:[selectedClass()||'All classes'];
    const subjects=[
      {name:'Mathematics',adjust:0,color:'var(--lavender-200)'},
      {name:'English',adjust:-3,color:'var(--purple)'},
      {name:'Basic Science',adjust:2,color:'var(--indigo-700)'}
    ];
    const width=560,left=36,right=12,plotW=width-left-right,plotH=142,base=166;
    let grid='<g stroke="var(--line)" stroke-width="1">'+[0,25,50,75,100].map(v=>'<line x1="'+left+'" y1="'+(base-v*plotH/100)+'" x2="'+(width-right)+'" y2="'+(base-v*plotH/100)+'"/>').join('')+'</g>';
    let labels='<g fill="var(--muted)" font-size="9">'+[0,25,50,75,100].map(v=>'<text x="3" y="'+(base-v*plotH/100+3)+'">'+v+'</text>').join('')+'</g>';
    let bars='',xlabels='',legend='',groupW=plotW/Math.max(groups.length,1),bw=Math.min(16,groupW/7);
    groups.forEach((cl,gi)=>{
      const classList=source.filter(s=>s.className===cl);
      const classAvg=classList.length?avg(classList):avg(filteredStudents());
      const baseX=left+gi*groupW+groupW*.17;
      subjects.forEach((subject,si)=>{
        const score=Math.max(0,Math.min(100,classAvg+subject.adjust));
        const h=score*plotH/100,x=baseX+si*(bw+5);
        bars+='<rect x="'+x+'" y="'+(base-h)+'" width="'+bw+'" height="'+h+'" rx="3" fill="'+subject.color+'"><title>'+escText(subject.name)+' · '+escText(cl)+': '+score+'%</title></rect>';
      });
      xlabels+='<text x="'+(left+gi*groupW+groupW/2)+'" y="185" text-anchor="middle" fill="var(--muted)" font-size="9">'+escText(cl)+'</text>';
    });
    legend=subjects.map(s=>'<span class="chart-key"><i style="background:'+s.color+'"></i>'+s.name+'</span>').join('');
    return '<div class="card"><div class="dashboard-section-head"><div><h2>Exam results by class</h2><p>Grouped comparison · based on saved assessment totals</p></div><span class="pill">'+escText($('overviewAssessmentFilter')?.value||'All assessments')+'</span></div><div class="dashboard-section-body"><svg class="exam-chart" viewBox="0 0 '+width+' 195" role="img" aria-label="Grouped exam result bars by class">'+grid+labels+bars+xlabels+'</svg><div class="chart-legend">'+legend+'</div></div></div>';
  }
  function renderAttendanceDonut(){
    const present=213,late=14,absent=21,total=present+late+absent;
    const pPct=present/total*100,lPct=late/total*100;
    return '<div class="card"><div class="dashboard-section-head"><div><h2>Attendance breakdown</h2><p>Present, late and absent · school overview</p></div><button class="dashboard-link" onclick="showView(\'attendance\')">Open register ↗</button></div><div class="attendance-summary-layout"><div class="attendance-donut" style="background:conic-gradient(var(--indigo-600) 0 '+pPct+'%,var(--purple) '+pPct+'% '+(pPct+lPct)+'%,var(--lavender-100) '+(pPct+lPct)+'% 100%)"><div class="attendance-donut-center"><strong>'+Math.round(pPct)+'%</strong><span>Present</span></div></div><div class="attendance-legend"><div class="attendance-legend-row"><span><i style="background:var(--indigo-600)"></i>Present</span><b>'+present+'</b></div><div class="attendance-legend-row"><span><i style="background:var(--purple)"></i>Late</span><b>'+late+'</b></div><div class="attendance-legend-row"><span><i style="background:var(--lavender-100)"></i>Absent</span><b>'+absent+'</b></div><div class="attendance-legend-row"><span>Total students</span><b>'+total+'</b></div></div></div></div>';
  }
  function renderSpotlightCards(){
    const list=filteredStudents();
    const sorted=[...list].sort((a,b)=>totalScore(b)-totalScore(a));
    const topMarks=sorted[0];
    const topAttendance=list.find(s=>(safeAttendance()[s.id]||'Present')==='Present')||list[0];
    const cards=[
      {label:'Best in Marks',s:topMarks,score:topMarks?totalScore(topMarks)+'%':'—',meta:topMarks?topMarks.className:'No records',foot:'Highest saved score'},
      {label:'Best in Attendance',s:topAttendance,score:topAttendance?'Present today':'—',meta:topAttendance?topAttendance.className:'No records',foot:'Historical attendance trend unavailable'},
      {label:'Most Improved in Marks',s:null,score:'—',meta:'Previous-term scores needed',foot:'Add historic scores to compare progress'},
      {label:'Most Improved in Attendance',s:null,score:'—',meta:'Previous attendance needed',foot:'Add historic registers to compare progress'}
    ];
    return '<div class="grid spotlight-grid">'+cards.map(c=>'<article class="card spotlight-card"><div class="spotlight-label">'+c.label+'</div><div class="spotlight-person"><div class="spotlight-avatar">'+(c.s?initialsText(c.s.name):'—')+'</div><div style="min-width:0"><div class="spotlight-name">'+escText(c.s?.name||'Trend data unavailable')+'</div><div class="spotlight-meta">'+escText(c.meta)+'</div></div></div><div class="spotlight-score">'+escText(c.score)+'</div><div class="spotlight-foot">'+escText(c.foot)+'</div></article>').join('')+'</div>';
  }
  function renderStudentDetails(){
    const list=filteredStudents(), sorted=[...list].sort((a,b)=>totalScore(b)-totalScore(a));
    const picks=[
      {label:'Top academic performer',s:sorted[0],sub:'Highest recorded total'},
      {label:'Needs academic support',s:sorted.slice().reverse()[0],sub:'Lowest recorded total'},
      {label:'Latest student record',s:list[0],sub:'Most recently listed in demo'}
    ];
    return '<div class="grid student-detail-grid">'+picks.map(p=>'<article class="card student-detail-card"><div class="spotlight-avatar">'+(p.s?initialsText(p.s.name):'—')+'</div><div class="student-detail-main"><div class="student-detail-title">'+p.label+'</div><div class="student-detail-name">'+escText(p.s?.name||'No student data')+'</div><div class="student-detail-sub">'+escText(p.s?.className||'')+' · '+p.sub+'</div></div><div class="student-detail-score">'+(p.s?totalScore(p.s)+'%':'—')+'</div></article>').join('')+'</div>';
  }
  function renderAverageRings(){
    const list=filteredStudents();
    const groups=['Primary 5','JSS 1','JSS 2','SS 1','SS 2'];
    const data=groups.map(cl=>({name:cl,list:list.filter(s=>s.className===cl)})).filter(x=>x.list.length);
    if(!data.length) data.push({name:selectedClass()||'All classes',list});
    return '<div class="card"><div class="dashboard-section-head"><div><h2>Average score by class</h2><p>Continuous assessment + exam · out of 100</p></div><button class="dashboard-link" onclick="showView(\'results\')">View results ↗</button></div><div class="average-rings">'+data.slice(0,4).map(d=>{const score=avg(d.list);return '<div class="average-ring-item"><div class="average-ring" style="--score:'+score+'"><strong>'+score+'%</strong></div><div class="average-ring-label">'+escText(d.name)+'</div><div class="average-ring-caption">'+d.list.length+' sample students</div></div>'}).join('')+'</div></div>';
  }
  function renderRecentAttendance(){
    const list=safeStudents().slice(0,4);
    return '<div class="card"><div class="dashboard-section-head"><div><h2>Recent attendance</h2><p>Quick view of today’s register</p></div><button class="dashboard-link" onclick="showView(\'attendance\')">Full register ↗</button></div><div class="table-wrap"><table><thead><tr><th>STUDENT</th><th>CLASS</th><th>STATUS</th></tr></thead><tbody>'+list.map(s=>'<tr><td><div class="person"><div class="mini-avatar">'+initialsText(s.name)+'</div><div><b>'+escText(s.name)+'</b><small>'+escText(s.id)+'</small></div></div></td><td>'+escText(s.className)+'</td><td>'+((safeAttendance()[s.id]||'Present')==='Absent'?'<span class="status absent">Absent</span>':(safeAttendance()[s.id]||'Present')==='Late'?'<span class="status late">Late</span>':'<span class="status present">Present</span>')+'</td></tr>').join('')+'</tbody></table></div></div>';
  }
  function renderQuickActions(){
    return '<div class="card"><div class="dashboard-section-head"><div><h2>Quick actions</h2><p>Common tasks in one click</p></div></div><div class="task-list"><div class="task" onclick="showView(\'teacher\')" style="cursor:pointer"><div class="task-icon">✦</div><div><b>Draft a lesson note</b><small>Prepare an editable teaching draft</small></div><span class="arrow">↗</span></div><div class="task" onclick="showView(\'results\')" style="cursor:pointer"><div class="task-icon" style="background:var(--amber-soft);color:var(--color-a66e0d)">▤</div><div><b>Enter assessment scores</b><small>Update totals and grade bands</small></div><span class="arrow">↗</span></div><div class="task" onclick="showView(\'students\')" style="cursor:pointer"><div class="task-icon" style="background:var(--purple-soft);color:var(--purple)">♙</div><div><b>Manage student records</b><small>Search, add and export records</small></div><span class="arrow">↗</span></div></div></div>';
  }
  window.renderOverview = function(){
    const host=$('overview'); if(!host) return;
    const current={
      className:$('overviewClassFilter')?.value||'',
      term:$('overviewTermFilter')?.value||'First term',
      assessment:$('overviewAssessmentFilter')?.value||'All assessments',
      session:$('overviewSessionFilter')?.value||'2026/2027'
    };
    host.innerHTML=renderDashboardIntro()+renderDashboardFilters()+
      renderKpiCards()+
      '<div class="grid dashboard-two-col">'+renderPerformanceBars()+renderAttendanceDonut()+'</div>'+
      '<div class="dashboard-section-head" style="padding-left:0;padding-right:0"><div><h2>Student spotlights</h2><p>Recognition and progress snapshots</p></div></div>'+renderSpotlightCards()+
      '<div class="dashboard-section-head" style="padding-left:0;padding-right:0"><div><h2>Student details</h2><p>Academic records at a glance</p></div><button class="dashboard-link" onclick="showView(\'students\')">Student directory ↗</button></div>'+renderStudentDetails()+
      '<div class="grid dashboard-two-col equal">'+renderAverageRings()+renderRecentAttendance()+'</div>'+
      '<div style="margin-top:16px">'+renderQuickActions()+'</div>';
    // Restore the user's selections after rebuilding the filter controls.
    $('overviewClassFilter').value=current.className;
    $('overviewTermFilter').value=current.term;
    $('overviewAssessmentFilter').value=current.assessment;
    $('overviewSessionFilter').value=current.session;
    $('overviewDate').textContent=new Date().toLocaleDateString('en-GB',{weekday:'long',day:'numeric',month:'long',year:'numeric'}).toUpperCase();
    const schoolName=$('schoolName')?.value;
    if(schoolName && $('schoolHeaderName')) $('schoolHeaderName').textContent=schoolName;
  };
})();
