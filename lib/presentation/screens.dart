import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/task_repository.dart';
import '../database/app_database.dart';
import 'taskflow_app.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}
class _TasksScreenState extends State<TasksScreen> {
  String search = '';
  String? status;
  String? priority;
  int? assignee;
  bool sortDeadline = false;
  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск задач...', border: OutlineInputBorder()), onChanged: (v) => setState(() => search = v))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
        Expanded(child: DropdownButtonFormField<String?>(value: status, decoration: const InputDecoration(labelText: 'Статус', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)), items: const [DropdownMenuItem(value: null, child: Text('Все')), DropdownMenuItem(value: 'todo', child: Text('Ожидает')), DropdownMenuItem(value: 'inProgress', child: Text('В работе')), DropdownMenuItem(value: 'done', child: Text('Готово')), DropdownMenuItem(value: 'cancelled', child: Text('Отменено'))], onChanged: (v) => setState(() => status = v))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String?>(value: priority, decoration: const InputDecoration(labelText: 'Приоритет', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)), items: const [DropdownMenuItem(value: null, child: Text('Все')), DropdownMenuItem(value: 'low', child: Text('Низкий')), DropdownMenuItem(value: 'medium', child: Text('Средний')), DropdownMenuItem(value: 'high', child: Text('Высокий')), DropdownMenuItem(value: 'critical', child: Text('Критический'))], onChanged: (v) => setState(() => priority = v))),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Expanded(child: StreamBuilder<List<User>>(stream: repo.watchUsers(), builder: (ctx, users) => DropdownButtonFormField<int?>(value: assignee, isExpanded: true, decoration: const InputDecoration(labelText: 'Исполнитель', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)), items: [const DropdownMenuItem<int?>(value: null, child: Text('Все исполнители')), ...(users.data ?? []).map((u) => DropdownMenuItem<int?>(value: u.id, child: Text(u.name)))], onChanged: (v) => setState(() => assignee = v)))),
        const SizedBox(width: 8),
        IconButton(tooltip: sortDeadline ? 'Сначала дедлайн' : 'Сначала новые', onPressed: () => setState(() => sortDeadline = !sortDeadline), icon: Icon(sortDeadline ? Icons.event : Icons.schedule)),
      ])),
      Expanded(child: StreamBuilder<List<Task>>(stream: repo.watchTasks(status: status, priority: priority, assigneeId: assignee, query: search, sortByDeadline: sortDeadline), builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snap.data!;
        if (tasks.isEmpty) return const Center(child: Text('Задач пока нет. Создайте первую задачу.'));
        return ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 88), itemCount: tasks.length, itemBuilder: (context, i) => TaskCard(task: tasks[i]));
      })),
      Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.all(16), child: FloatingActionButton.extended(onPressed: () => createTaskDialog(context), icon: const Icon(Icons.add), label: const Text('Новая задача')))),
    ]);
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({super.key, required this.task});
  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    final statusNames = {'todo':'Ожидает','inProgress':'В работе','done':'Готово','cancelled':'Отменено'};
    final priorityNames = {'low':'Низкий','medium':'Средний','high':'Высокий','critical':'Критический'};
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))), PopupMenuButton<String>(onSelected: (v) async { try { if (v == 'delete') { await repo.softDeleteTask(task.id); } else if (v == 'undo') { await repo.undoStatus(task.id); } else if (v == 'comments') { if (context.mounted) showTaskDetails(context, task); } else if (v == 'edit') { if (context.mounted) editTaskDialog(context, task); } else if (v == 'assign') { if (context.mounted) reassignTaskDialog(context, task); } } catch (e) { if (context.mounted) showError(context, e); } }, itemBuilder: (_) => const [PopupMenuItem(value:'edit', child: Text('Редактировать')), PopupMenuItem(value:'assign', child: Text('Назначить исполнителя')), PopupMenuItem(value:'comments', child: Text('Комментарии и история')), PopupMenuItem(value:'undo', child: Text('Отменить статус')), PopupMenuItem(value:'delete', child: Text('В корзину'))])]),
      if (task.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        Chip(label: Text(priorityNames[task.priority] ?? task.priority)),
        Chip(label: Text(statusNames[task.status] ?? task.status)),
        if (task.deadline != null) Chip(avatar: const Icon(Icons.event, size: 16), label: Text(DateTime.fromMillisecondsSinceEpoch(task.deadline!).toLocal().toString().substring(0, 10))),
      ]),
      Align(alignment: Alignment.centerRight, child: DropdownButton<String>(value: task.status, underline: const SizedBox(), hint: const Text('Статус'), items: statusNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) async { if (v != null) { try { await repo.changeStatus(task.id, v); } catch (e) { if (context.mounted) showError(context, e); } } })),
    ])));
  }
}

Future<void> createTaskDialog(BuildContext context) async {
  final repo = context.read<TaskRepository>();
  final projects = await repo.watchProjects().first;
  final users = await repo.watchUsers().first;
  if (!context.mounted) return;
  if (projects.isEmpty) { showError(context, 'Сначала создайте проект'); return; }
  final title = TextEditingController(); final desc = TextEditingController();
  int projectId = projects.first.id; int? userId; String priority = 'medium'; DateTime? deadline;
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    title: const Text('Новая задача'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Название')),
      TextField(controller: desc, decoration: const InputDecoration(labelText: 'Описание'), maxLines: 3),
      DropdownButtonFormField<int>(value: projectId, decoration: const InputDecoration(labelText: 'Проект'), items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) { if (v != null) set(() => projectId = v); }),
      DropdownButtonFormField<int?>(value: userId, decoration: const InputDecoration(labelText: 'Исполнитель'), items: [const DropdownMenuItem(value: null, child: Text('Не назначен')), ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))], onChanged: (v) => set(() => userId = v)),
      DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'Приоритет'), items: const [DropdownMenuItem(value:'low',child:Text('Низкий')),DropdownMenuItem(value:'medium',child:Text('Средний')),DropdownMenuItem(value:'high',child:Text('Высокий')),DropdownMenuItem(value:'critical',child:Text('Критический'))], onChanged: (v) => set(() => priority = v ?? 'medium')),
      TextButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: DateTime.now()); if (d != null) set(() => deadline = d); }, icon: const Icon(Icons.calendar_month), label: Text(deadline == null ? 'Выбрать дедлайн' : deadline!.toString().substring(0,10))),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () async { try { await repo.createTask(title: title.text, description: desc.text, projectId: projectId, assigneeId: userId, priority: priority, deadline: deadline?.millisecondsSinceEpoch); if (ctx.mounted) Navigator.pop(ctx); } catch (e) { if (ctx.mounted) showError(ctx, e); } }, child: const Text('Создать'))],
  )));
}
Future<void> editTaskDialog(BuildContext context, Task task) async {
  final repo = context.read<TaskRepository>(); final title = TextEditingController(text: task.title); final desc = TextEditingController(text: task.description); String priority = task.priority; DateTime? deadline = task.deadline == null ? null : DateTime.fromMillisecondsSinceEpoch(task.deadline!);
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx,set) => AlertDialog(title: const Text('Редактировать задачу'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller:title,decoration:const InputDecoration(labelText:'Название')),TextField(controller:desc,decoration:const InputDecoration(labelText:'Описание'),maxLines:3),DropdownButtonFormField<String>(value:priority,items:const [DropdownMenuItem(value:'low',child:Text('Низкий')),DropdownMenuItem(value:'medium',child:Text('Средний')),DropdownMenuItem(value:'high',child:Text('Высокий')),DropdownMenuItem(value:'critical',child:Text('Критический'))],onChanged:(v)=>set(()=>priority=v??'medium')),TextButton(onPressed:() async { final d=await showDatePicker(context:ctx,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime.now().add(const Duration(days:3650)),initialDate:deadline??DateTime.now()); if(d!=null)set(()=>deadline=d); },child:Text(deadline?.toString().substring(0,10)??'Дедлайн не задан'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Отмена')),FilledButton(onPressed:() async {try{await repo.updateTask(task.id,title:title.text,description:desc.text,priority:priority,deadline:deadline?.millisecondsSinceEpoch);if(ctx.mounted)Navigator.pop(ctx);}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Сохранить'))])));
}

Future<void> showTaskDetails(BuildContext context, Task task) async {
  final repo = context.read<TaskRepository>(); final comment = TextEditingController();
  final users = await repo.watchUsers().first; if (!context.mounted) return;
  int authorId = users.isEmpty ? 0 : users.first.id;
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx,set) => AlertDialog(
    title: Text(task.title), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Комментарии', style: TextStyle(fontWeight: FontWeight.bold)),
      StreamBuilder<List<Comment>>(stream: repo.watchComments(task.id), builder: (ctx,s) => Column(children: (s.data ?? []).map((c) => ListTile(title:Text(c.body),subtitle:Text('Автор ID: ${c.authorId}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:() async {try{await repo.deleteComment(c.id,authorId);}catch(e){if(ctx.mounted)showError(ctx,e);}}))).toList())),
      TextField(controller:comment,decoration:const InputDecoration(labelText:'Новый комментарий')),
      DropdownButton<int>(value: authorId == 0 ? null : authorId, items: users.map((u)=>DropdownMenuItem(value:u.id,child:Text(u.name))).toList(), onChanged:(v)=>set(()=>authorId=v??authorId)),
      const Divider(), const Text('История изменений',style:TextStyle(fontWeight:FontWeight.bold)),
      StreamBuilder<List<TaskHistoryData>>(stream:repo.watchHistory(task.id),builder:(ctx,s)=>Column(children:(s.data??[]).map((h)=>ListTile(dense:true,title:Text('${h.previousStatus??"—"} → ${h.newStatus}'),subtitle:Text(h.details.isEmpty?DateTime.fromMillisecondsSinceEpoch(h.changedAt).toString():h.details))).toList())),
      const Divider(), const Text('Вложения',style:TextStyle(fontWeight:FontWeight.bold)),
      StreamBuilder<List<Attachment>>(stream:repo.watchAttachments(task.id),builder:(ctx,s)=>Column(children:(s.data??[]).map((a)=>ListTile(dense:true,leading:const Icon(Icons.attach_file),title:Text(a.fileName),subtitle:Text(a.localPath))).toList())),
      TextButton.icon(onPressed:() async { final f=await FilePicker.platform.pickFiles(); if(f!=null && f.files.single.path!=null){await repo.addAttachment(task.id,f.files.single.name,f.files.single.path!);}},icon:const Icon(Icons.attach_file),label:const Text('Прикрепить файл')),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Закрыть')),FilledButton(onPressed:() async {try{await repo.addComment(task.id,authorId,comment.text);comment.clear();}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Добавить комментарий'))],
  )));
}

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo=context.read<TaskRepository>();
    return Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:() async {final users=await repo.watchUsers().first;if(!context.mounted)return;if(users.isEmpty){showError(context,'Сначала добавьте пользователя');return;}final n=TextEditingController();final d=TextEditingController();int owner=users.first.id;await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('Новый проект'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Название')),TextField(controller:d,decoration:const InputDecoration(labelText:'Описание')),DropdownButton<int>(value:owner,items:users.map((u)=>DropdownMenuItem(value:u.id,child:Text(u.name))).toList(),onChanged:(v)=>set(()=>owner=v??owner))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Отмена')),FilledButton(onPressed:()async{try{await repo.addProject(n.text,d.text,owner);if(ctx.mounted)Navigator.pop(ctx);}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Создать'))])));},icon:const Icon(Icons.add),label:const Text('Проект')),body:StreamBuilder<List<Project>>(stream:repo.watchProjects(),builder:(ctx,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Проектов пока нет'));return ListView(padding:const EdgeInsets.all(12),children:s.data!.map((p)=>Card(child:ListTile(leading:const Icon(Icons.folder_outlined),title:Text(p.name),subtitle:Text(p.description),onTap:()=>showProjectTasks(ctx,p),trailing:PopupMenuButton<String>(onSelected:(v)async{try{if(v=='delete')await repo.deleteProject(p.id);if(v=='members')await manageMembersDialog(ctx,p);if(v=='edit')await editProjectDialog(ctx,p);if(v=='complete')await repo.updateProject(p.id,p.name,p.description,'completed');if(v=='archive')await repo.updateProject(p.id,p.name,p.description,'archived');}catch(e){if(ctx.mounted)showError(ctx,e);}},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Редактировать')),PopupMenuItem(value:'members',child:Text('Участники проекта')),PopupMenuItem(value:'complete',child:Text('Завершить')),PopupMenuItem(value:'archive',child:Text('Архивировать')),PopupMenuItem(value:'delete',child:Text('Удалить'))])))).toList());}));
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo=context.read<TaskRepository>();
    return Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()async{final n=TextEditingController();final e=TextEditingController();await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Новый участник'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Имя')),TextField(controller:e,decoration:const InputDecoration(labelText:'Email'),keyboardType:TextInputType.emailAddress)]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Отмена')),FilledButton(onPressed:()async{try{await repo.addUser(n.text,e.text);if(ctx.mounted)Navigator.pop(ctx);}catch(err){if(ctx.mounted)showError(ctx,err);}},child:const Text('Добавить'))]));},icon:const Icon(Icons.person_add),label:const Text('Участник')),body:StreamBuilder<List<User>>(stream:repo.watchUsers(),builder:(ctx,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(12),children:s.data!.map((u)=>Card(child:ListTile(leading:CircleAvatar(child:Text(u.name.isEmpty?'?':u.name[0].toUpperCase())),title:Text(u.name),subtitle:Text(u.email),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='delete'){try{await repo.deleteUser(u.id);}catch(e){if(ctx.mounted)showError(ctx,e);}}if(v=='edit' && ctx.mounted) await editUserDialog(ctx,u);if(v=='tasks' && ctx.mounted) await showUserTasks(ctx,u);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Редактировать')),PopupMenuItem(value:'tasks',child:Text('Задачи пользователя')),PopupMenuItem(value:'delete',child:Text('Удалить'))])))).toList());}));
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo=context.read<TaskRepository>();
    return FutureBuilder<List<Map<String,Object?>>>(future:repo.dashboard(),builder:(ctx,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final d=s.data!.first;return ListView(padding:const EdgeInsets.all(16),children:[
      GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:1.6,children:[
        StatTile('Проекты',d['project_count']),StatTile('Всего задач',d['task_count']),StatTile('Завершено',d['done_count']),StatTile('В работе',d['open_count']),StatTile('Просрочено',d['overdue_count']),
      ]),
      const SizedBox(height:12),const Text('Задачи по приоритетам',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      FutureBuilder<List<Map<String,Object?>>>(future:repo.statsByPriority(),builder:(c,v)=>Column(children:(v.data??[]).map((r)=>ListTile(title:Text(r['priority'].toString()),trailing:Text(r['amount'].toString()))).toList())),
      const Text('Задачи по исполнителям',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      FutureBuilder<List<Map<String,Object?>>>(future:repo.statsByAssignee(),builder:(c,v)=>Column(children:(v.data??[]).map((r)=>ListTile(title:Text(r['name'].toString()),trailing:Text(r['amount'].toString()))).toList())),
      const Text('Прогресс проектов',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      FutureBuilder<List<Map<String,Object?>>>(future:repo.projectProgress(),builder:(c,v)=>Column(children:(v.data??[]).map((r){final total=(r['total'] as int?)??0;final done=(r['done'] as int?)??0;final p=total==0?0.0:done/total;return ListTile(title:Text(r['name'].toString()),subtitle:LinearProgressIndicator(value:p),trailing:Text('${(p*100).round()}%'));}).toList())),
    ]);});
  }
}
class StatTile extends StatelessWidget {
  final String label; final Object? value;
  const StatTile(this.label,this.value,{super.key});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value?.toString()??'0',style:Theme.of(context).textTheme.headlineMedium),Text(label)])));
}

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo=context.read<TaskRepository>();
    return StreamBuilder<List<Task>>(stream:repo.watchTasks(trash:true),builder:(ctx,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Корзина пуста'));return ListView(children:s.data!.map((t)=>Card(child:ListTile(title:Text(t.title),subtitle:Text(t.description),trailing:Wrap(children:[IconButton(tooltip:'Восстановить',icon:const Icon(Icons.restore),onPressed:()=>repo.restoreTask(t.id)),IconButton(tooltip:'Удалить навсегда',icon:const Icon(Icons.delete_forever),onPressed:()=>repo.permanentlyDeleteTask(t.id))])))).toList());});
  }
}

Future<void> manageMembersDialog(BuildContext context, Project project) async {
  final repo = context.read<TaskRepository>();
  final users = await repo.watchUsers().first;
  if (!context.mounted) return;
  int? selected = users.isEmpty ? null : users.first.id;
  String role = 'Member';
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    title: Text('Участники: ${project.name}'),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      FutureBuilder<List<Map<String,Object?>>>(future: repo.projectMembers(project.id), builder: (ctx,s) => Column(children: (s.data ?? []).map((m) => ListTile(dense:true,title:Text(m['name'].toString()),subtitle:Text('${m['email']} • ${m['role']}'),trailing:IconButton(icon:const Icon(Icons.person_remove_outlined),onPressed:() async {try{await repo.removeMember(project.id,m['id'] as int);set((){});}catch(e){if(ctx.mounted)showError(ctx,e);}}))).toList())),
      const Divider(),
      if(users.isNotEmpty) DropdownButton<int>(value:selected, isExpanded:true, items:users.map((u)=>DropdownMenuItem(value:u.id,child:Text(u.name))).toList(),onChanged:(v)=>set(()=>selected=v)),
      DropdownButton<String>(value:role,isExpanded:true,items:const [DropdownMenuItem(value:'Owner',child:Text('Owner')),DropdownMenuItem(value:'Admin',child:Text('Admin')),DropdownMenuItem(value:'Member',child:Text('Member'))],onChanged:(v)=>set(()=>role=v??'Member')),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Закрыть')),FilledButton(onPressed:selected==null?null:()async{try{await repo.addMember(project.id,selected!,role);set((){});}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Добавить участника'))],
  )));
}

Future<void> editUserDialog(BuildContext context, User user) async {
  final repo=context.read<TaskRepository>(); final name=TextEditingController(text:user.name); final email=TextEditingController(text:user.email);
  await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Редактировать участника'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Имя')),TextField(controller:email,decoration:const InputDecoration(labelText:'Email'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Отмена')),FilledButton(onPressed:()async{try{await repo.updateUser(user.id,name.text,email.text);if(ctx.mounted)Navigator.pop(ctx);}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Сохранить'))]));
}
Future<void> showUserTasks(BuildContext context, User user) async {
  final repo=context.read<TaskRepository>();
  await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('Задачи: ${user.name}'),content:SizedBox(width:420,height:400,child:StreamBuilder<List<Task>>(stream:repo.watchTasks(assigneeId:user.id),builder:(ctx,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('Назначенных задач нет'));return ListView(children:s.data!.map((t)=>ListTile(title:Text(t.title),subtitle:Text(t.status))).toList());})),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Закрыть'))]));
}

Future<void> reassignTaskDialog(BuildContext context, Task task) async {
  final repo=context.read<TaskRepository>();
  final members=await repo.projectMembers(task.projectId);
  if(!context.mounted)return;
  int? selected=task.assigneeId;
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('Назначить исполнителя'),content:DropdownButton<int?>(isExpanded:true,value:selected,items:[const DropdownMenuItem<int?>(value:null,child:Text('Не назначен')),...members.map((m)=>DropdownMenuItem<int?>(value:m['id'] as int,child:Text('${m['name']} (${m['role']})')))],onChanged:(v)=>set(()=>selected=v)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Отмена')),FilledButton(onPressed:()async{try{await repo.reassignTask(task.id,selected);if(ctx.mounted)Navigator.pop(ctx);}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Сохранить'))])));
}

Future<void> editProjectDialog(BuildContext context, Project project) async {
  final repo=context.read<TaskRepository>();final name=TextEditingController(text:project.name);final description=TextEditingController(text:project.description);String status=project.status;
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('Редактировать проект'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Название')),TextField(controller:description,decoration:const InputDecoration(labelText:'Описание')),DropdownButton<String>(value:status,items:const [DropdownMenuItem(value:'active',child:Text('Активный')),DropdownMenuItem(value:'completed',child:Text('Завершённый')),DropdownMenuItem(value:'archived',child:Text('Архивный'))],onChanged:(v)=>set(()=>status=v??'active'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Отмена')),FilledButton(onPressed:()async{try{await repo.updateProject(project.id,name.text,description.text,status,dueAt:project.dueAt);if(ctx.mounted)Navigator.pop(ctx);}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Сохранить'))])));
}
Future<void> showProjectTasks(BuildContext context, Project project) async {
  final repo=context.read<TaskRepository>();
  await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('Задачи проекта: ${project.name}'),content:SizedBox(width:440,height:420,child:StreamBuilder<List<Task>>(stream:repo.watchTasks(projectId:project.id),builder:(ctx,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('В проекте пока нет задач'));return ListView(children:s.data!.map((t)=>ListTile(title:Text(t.title),subtitle:Text('${t.status} • ${t.priority}'))).toList());})),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Закрыть'))]));
}
