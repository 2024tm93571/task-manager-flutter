import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'NjhPOwCO8Zspi7qSTG8w8AtkLKyNsN5677Bc2eBQ';
  const keyClientKey = 'rdszakUxonFgeRjdeZe7us2QLkwrGIGtow3FMVsB';
  const keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(
    keyApplicationId,
    keyParseServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
    debug: true,
  );

  // Clear any invalid session on startup
  final currentUser = await ParseUser.currentUser() as ParseUser?;
  if (currentUser != null) {
    try {
      final response = await ParseUser.getCurrentUserFromServer(currentUser.sessionToken!);
      if (response == null || !response.success) {
        await currentUser.logout();
      }
    } catch (e) {
      await currentUser.logout();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// ==========================================
// LOGIN PAGE
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final username = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Clear old session first
    final oldUser = await ParseUser.currentUser() as ParseUser?;
    if (oldUser != null) await oldUser.logout();

    final user = ParseUser(username, password, username);
    final response = await user.login();

    setState(() => _isLoading = false);

    if (response.success) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TaskListPage()),
        );
      }
    } else {
      _showMessage('Login failed: ${response.error?.message}');
    }
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    final username = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password');
      setState(() => _isLoading = false);
      return;
    }

    final user = ParseUser(username, password, username);
    final response = await user.signUp();

    setState(() => _isLoading = false);

    if (response.success) {
      _showMessage('Registration successful! Please login.');
    } else {
      _showMessage('Registration failed: ${response.error?.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.task_alt, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 16),
              const Text(
                'Task Manager',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your tasks in the cloud',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email / Username',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('LOGIN', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _register,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('REGISTER', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TASK LIST PAGE
// ==========================================
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (mounted) setState(() => _isLoading = true);

    final currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser == null) return;

    final query = QueryBuilder<ParseObject>(ParseObject('Task'))
      ..whereEqualTo('user', currentUser)
      ..orderByDescending('createdAt');

    final response = await query.query();

    if (mounted) {
      setState(() {
        if (response.success && response.results != null) {
          _tasks = response.results!.map((r) {
            final obj = r as ParseObject;
            return {
              'id': obj.objectId ?? '',
              'object': obj,
              'title': obj.get<String>('title') ?? '',
              'description': obj.get<String>('description') ?? '',
              'isDone': obj.get<bool>('isDone') ?? false,
            };
          }).toList();
        } else {
          _tasks = [];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTask(String objectId) async {
    print('=== DELETE CALLED for objectId: $objectId');
    print('=== Tasks before delete: ${_tasks.length}');

    final matchingTasks = _tasks.where((t) => t['id'] == objectId).toList();
    print('=== Matching tasks found: ${matchingTasks.length}');

    if (matchingTasks.isEmpty) {
      _showMessage('Task not found locally');
      return;
    }

    final parseObject = matchingTasks.first['object'] as ParseObject;
    print('=== ParseObject objectId: ${parseObject.objectId}');

    final response = await parseObject.delete();
    print('=== Delete success: ${response.success}');
    print('=== Delete error: ${response.error?.message}');

    if (response.success) {
      if (mounted) {
        final newList = _tasks.where((t) => t['id'] != objectId).toList();
        print('=== New list length: ${newList.length}');
        setState(() {
          _tasks = newList;
        });
        _showMessage('Task deleted!');
      }
    } else {
      _showMessage('Delete failed: ${response.error?.message}');
    }
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _logout() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    await user?.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _openTaskForm({ParseObject? task}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskFormPage(task: task)),
    );
    _loadTasks();
  }

  void _confirmDelete(String objectId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTask(objectId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tasks yet!\nTap + to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final taskMap = _tasks[index];
            final objectId = taskMap['id'] as String;
            final title = taskMap['title'] as String;
            final description = taskMap['description'] as String;
            final isDone = taskMap['isDone'] as bool;
            final parseObject = taskMap['object'] as ParseObject;

            return Card(
              key: ValueKey(objectId), // unique key per task
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: isDone
                      ? Colors.green.shade100
                      : Colors.deepPurple.shade100,
                  child: Icon(
                    isDone ? Icons.check : Icons.task,
                    color: isDone ? Colors.green : Colors.deepPurple,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: description.isNotEmpty
                    ? Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _openTaskForm(task: parseObject),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(objectId, title),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}

// ==========================================
// TASK FORM PAGE (Create & Edit)
// ==========================================
class TaskFormPage extends StatefulWidget {
  final ParseObject? task;

  const TaskFormPage({super.key, this.task});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isDone = false;
  bool _isSaving = false;
  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.task!.get<String>('title') ?? '';
      _descController.text = widget.task!.get<String>('description') ?? '';
      _isDone = widget.task!.get<bool>('isDone') ?? false;
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final currentUser = await ParseUser.currentUser() as ParseUser?;

    final task = _isEditing ? widget.task! : ParseObject('Task');
    task.set('title', _titleController.text.trim());
    task.set('description', _descController.text.trim());
    task.set('isDone', _isDone);

    if (!_isEditing && currentUser != null) {
      task.set('user', currentUser);
      final acl = ParseACL(owner: currentUser);
      task.setACL(acl);
    }

    final response = await task.save();

    setState(() => _isSaving = false);

    if (response.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Task updated!' : 'Task created!')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.error?.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title *',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Complete assignment',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                    hintText: 'Add more details about this task...',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Mark as Completed'),
                  value: _isDone,
                  activeColor: Colors.deepPurple,
                  onChanged: (val) => setState(() => _isDone = val),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      _isEditing ? 'UPDATE TASK' : 'CREATE TASK',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}