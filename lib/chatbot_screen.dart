import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../services/chatbot_service.dart';
import '../models/chat_message.dart';
import '../widgets/feedback_dialog.dart';

class ChatbotScreen extends StatefulWidget {
  final int userId;
  final String userRole;
  final String userName;

  const ChatbotScreen({
    super.key,
    required this.userId,
    required this.userRole,
    required this.userName,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _suggestionsScrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final FocusNode _textFieldFocus = FocusNode();
  
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isTyping = false;
  String? _sessionId;
  
  List<String> _suggestions = [];
  Map<String, List<dynamic>> _commonQuestions = {};
  bool _showCommonQuestions = true;
  bool _isLoadingHistory = true;
  double _lastDialogScrollPosition = 0.0; // Store last scroll position
  
  // Enhanced animation controllers
  late AnimationController _suggestionsAnimController;
  late Animation<double> _suggestionsAnimation;
  late AnimationController _welcomeAnimController;
  late Animation<double> _welcomeAnimation;
  
  // New: Message send animation
  late AnimationController _messageSendAnimController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    
    // Initialize animations
    _suggestionsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _suggestionsAnimation = CurvedAnimation(
      parent: _suggestionsAnimController,
      curve: Curves.easeInOut,
    );
    
    _welcomeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _welcomeAnimation = CurvedAnimation(
      parent: _welcomeAnimController,
      curve: Curves.easeOut,
    );
    
    _messageSendAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _initializeChatbot();
    
    // Auto-scroll when keyboard appears
    _textFieldFocus.addListener(() {
      if (_textFieldFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  Future<void> _initializeChatbot() async {
    setState(() => _isLoadingHistory = true);
    
_sessionId = await ChatbotService.getSessionId(widget.userId, widget.userRole);    
    if (_sessionId != null) {
      await _loadHistory();
    } else {
      await _sendInitialGreeting();
    }
    
    _commonQuestions = await ChatbotService.getCommonQuestions(
      userRole: widget.userRole,
    );
    
    _loadAllSuggestions();
    
    setState(() => _isLoadingHistory = false);
    
    // Animate suggestions in
    if (_suggestions.isNotEmpty) {
      _suggestionsAnimController.forward();
    }
    
    // Animate welcome banner
    _welcomeAnimController.forward();
  }

  void _loadAllSuggestions() {
    List<String> allQuestions = [];
    
    // Prioritize categories based on user role
    final priorityOrder = widget.userRole == 'Student'
        ? ['schedule', 'exam', 'teacher', 'announcements', 'admissions', 'fee', 'scholarship', 'hostel', 'transport', 'library', 'university', 'facilities', 'general']
        : ['schedule', 'announcements', 'university', 'admissions', 'fee', 'facilities', 'general'];
    
    for (var category in priorityOrder) {
      if (_commonQuestions.containsKey(category)) {
        for (var q in _commonQuestions[category]!) {
          if (!allQuestions.contains(q['question'])) {
            allQuestions.add(q['question']);
          }
        }
      }
    }
    
    // Add any remaining categories
    _commonQuestions.forEach((category, questions) {
      if (!priorityOrder.contains(category)) {
        for (var q in questions) {
          if (!allQuestions.contains(q['question'])) {
            allQuestions.add(q['question']);
          }
        }
      }
    });
    
    setState(() {
      _suggestions = allQuestions;
    });
  }

  Future<void> _sendInitialGreeting() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final roleSpecificGreeting = widget.userRole == 'Student'
        ? "Hey ${widget.userName}! 👋\n\nI'm your campus assistant. I can help you with:\n\n"
          "📅 **Class Schedules** - Today, tomorrow, or any day\n"
          "👨‍🏫 **Teacher Info** - Contact details and schedules\n"
          "📢 **Announcements** - Stay updated\n"
          "📋 **Complaints** - Track your submissions\n"
          "🎓 **Admissions** - Programs and process\n"
          "💰 **Fee & Scholarships** - Financial information\n"
          "🏢 **Facilities** - Hostel, transport, library\n\n"
          "Just ask me anything in English or Urdu!"
        : "Hello ${widget.userName}! 👋\n\nI'm your campus assistant. I can help you with:\n\n"
          "📅 **Teaching Schedule** - Your classes and timings\n"
          "📢 **Announcements** - Latest updates\n"
          "🎓 **University Info** - General information\n"
          "🏢 **Facilities** - Campus facilities\n\n"
          "Ask me anything you need!";
    
    setState(() {
      _messages.add(ChatMessage.bot(
        roleSpecificGreeting,
        intent: 'greeting',
      ));
    });
    
    // Scroll after greeting is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadHistory() async {
    if (_sessionId == null) return;
    
final history = await ChatbotService.getHistory(
  sessionId: _sessionId!,
  userId: widget.userId,
  userRole: widget.userRole,
);    
    if (history.isNotEmpty) {
      setState(() {
        _messages.clear();
        for (var msg in history) {
          final chatMsg = ChatMessage.fromJson(msg);
          _messages.add(ChatMessage.user(chatMsg.message));
          _messages.add(ChatMessage.bot(
            chatMsg.response,
            intent: chatMsg.intent,
            confidence: chatMsg.confidence,
            id: chatMsg.id,
          ));
        }
      });
      // Scroll after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Animate send button
    _messageSendAnimController.forward().then((_) {
      _messageSendAnimController.reverse();
    });

    setState(() {
      _messages.add(ChatMessage.user(message));
      _isTyping = true;
      _showCommonQuestions = false;
    });

    _controller.clear();
    _textFieldFocus.unfocus();
    _scrollToBottom();

    try {
      final response = await ChatbotService.sendMessage(
        userId: widget.userId,
        userRole: widget.userRole,
        message: message,
        sessionId: _sessionId,
        userFullName: widget.userName,
      );

      if (response['sessionId'] != null) {
  _sessionId = response['sessionId'];
  await ChatbotService.saveSessionId(_sessionId!, widget.userId, widget.userRole);
}

      setState(() {
        _messages.add(ChatMessage.bot(
          response['response'] ?? 'Sorry, I couldn\'t process that.',
          intent: response['intent'],
          confidence: response['confidence'],
          id: response['messageId'],
        ));
        
        // Update suggestions with animation
        if (response['suggestions'] != null && 
            (response['suggestions'] as List).isNotEmpty) {
          _suggestions = List<String>.from(response['suggestions']);
          _suggestionsAnimController.reset();
          _suggestionsAnimController.forward();
        } else {
          _loadAllSuggestions();
        }
        
        _isTyping = false;
      });

      _scrollToBottom();
      
      // Show helpful tip for first-time users
      if (_messages.length == 2) {
        _showFirstTimeUserTip();
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage.bot(
          'Sorry, I encountered an error. Please check your internet connection and try again.',
        ));
        _isTyping = false;
      });
      
      _showErrorSnackBar('Connection error. Please try again.');
    }
  }

  void _showFirstTimeUserTip() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Tap the suggestions below or use the mic button to speak!',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              
              // Auto-send message when speech recognition completes
              if (_controller.text.trim().isNotEmpty) {
                print('Auto-sending message: ${_controller.text}');
                _sendMessage(_controller.text);
              }
            }
          }
        },
        onError: (error) {
          print('Speech error: $error');
          if (mounted) {
            setState(() => _isListening = false);
            
            // Don't show timeout errors (normal behavior)
            if (!error.errorMsg.contains('timeout') && 
                !error.errorMsg.contains('no-speech')) {
              _showErrorSnackBar('Speech recognition error: ${error.errorMsg}');
            }
          }
        },
      );

      if (available) {
        if (mounted) {
          setState(() => _isListening = true);
        }
        
        _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _controller.text = result.recognizedWords;
              });
              print('Recognized: ${result.recognizedWords}');
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      } else {
        if (mounted) {
          _showErrorSnackBar('Speech recognition not available on this device');
        }
      }
    } else {
      // Manual stop (when user presses mic button again)
      if (mounted) {
        setState(() => _isListening = false);
      }
      _speech.stop();
      
      // Send message if there's text
      if (_controller.text.trim().isNotEmpty) {
        print('Manual send: ${_controller.text}');
        _sendMessage(_controller.text);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Clear Chat?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'This will permanently delete all messages from this conversation. This action cannot be undone.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true && _sessionId != null) {
final success = await ChatbotService.clearConversation(
  sessionId: _sessionId!,
  userId: widget.userId,
  userRole: widget.userRole,
);      if (success) {
await ChatbotService.clearSessionId(widget.userId, widget.userRole);        setState(() {
          _messages.clear();
          _sessionId = null;
          _showCommonQuestions = true;
        });
        _sendInitialGreeting();
        _loadAllSuggestions();
        _welcomeAnimController.forward(from: 0);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Conversation cleared successfully'),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        _showErrorSnackBar('Failed to clear conversation. Please try again.');
      }
    }
  }

  void _showCommonQuestionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          // Restore scroll position after dialog is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients && _lastDialogScrollPosition > 0) {
              scrollController.jumpTo(
                _lastDialogScrollPosition.clamp(
                  0.0,
                  scrollController.position.maxScrollExtent,
                ),
              );
            }
          });
          
          // Listen to scroll changes to save position
          scrollController.addListener(() {
            _lastDialogScrollPosition = scrollController.offset;
          });
          
          return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.question_answer,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Common Questions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tap any question to ask',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Questions list - use the scroll controller from DraggableScrollableSheet
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: _commonQuestions.entries.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category.key),
                                size: 20,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatCategoryName(category.key),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...category.value.map((question) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                question['question'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _sendMessage(question['question']);
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ));
        },
      ),
    ).then((_) {
      // Optional: Reset scroll position if you want to start fresh next time
      // _lastDialogScrollPosition = 0.0;
    });
  }

  IconData _getCategoryIcon(String category) {
    final Map<String, IconData> icons = {
      'schedule': Icons.calendar_today,
      'teacher': Icons.person,
      'complaints': Icons.report_problem_outlined,
      'announcements': Icons.campaign,
      'exam': Icons.school,
      'university': Icons.account_balance,
      'admissions': Icons.how_to_reg,
      'fee': Icons.attach_money,
      'scholarship': Icons.card_giftcard,
      'hostel': Icons.home,
      'transport': Icons.directions_bus,
      'library': Icons.local_library,
      'facilities': Icons.apartment,
      'departments': Icons.business,
      'services': Icons.settings,
      'help': Icons.help_outline,
      'general': Icons.info_outline,
    };
    return icons[category.toLowerCase()] ?? Icons.help_outline;
  }

  String _formatCategoryName(String category) {
    final Map<String, String> categoryNames = {
      'schedule': 'Class Schedule',
      'teacher': 'Teachers',
      'complaints': 'Complaints',
      'announcements': 'Announcements',
      'exam': 'Exams & Results',
      'university': 'University Info',
      'admissions': 'Admissions',
      'fee': 'Fee Structure',
      'scholarship': 'Scholarships',
      'hostel': 'Hostel',
      'transport': 'Transport',
      'library': 'Library',
      'facilities': 'Campus Facilities',
      'departments': 'Departments',
      'services': 'Student Services',
      'help': 'Help & Support',
      'general': 'General',
    };
    return categoryNames[category] ?? 
           category.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Campus Assistant",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  "PMAS-AAUR Chatbot",
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.question_answer_outlined),
            tooltip: 'Common Questions',
            onPressed: _showCommonQuestionsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Chat',
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty && !_isLoadingHistory)
            _buildWelcomeBanner(),

          Expanded(
            child: _isLoadingHistory
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF38ef7d)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading conversation...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return _buildTypingIndicator();
                      }

                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          if (_suggestions.isNotEmpty) _buildSuggestions(),

          if (_showCommonQuestions && _messages.isEmpty && !_isLoadingHistory)
            _buildQuickQuestions(),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return FadeTransition(
      opacity: _welcomeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(_welcomeAnimation),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38ef7d).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hi ${widget.userName}! 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.userRole == 'Student'
                    ? 'I\'m your campus assistant for PMAS-AAUR,\nready to help with schedules, teachers,\nadmissions, and more!'
                    : 'I\'m your campus assistant for PMAS-AAUR,\nready to help with your schedule and\ncampus information!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final quickQuestions = _suggestions.take(4).toList();
    
    if (quickQuestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Try asking:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickQuestions.map((q) {
              return ActionChip(
                label: Text(
                  q,
                  style: const TextStyle(fontSize: 13),
                ),
                avatar: Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.green.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: () => _sendMessage(q),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return AnimatedBuilder(
      animation: _suggestionsAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _suggestionsAnimation.value)),
          child: Opacity(
            opacity: _suggestionsAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 130),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Suggested Questions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  if (_suggestions.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_suggestions.length} questions',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.swipe,
                            size: 12,
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                controller: _suggestionsScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(
                        _suggestions[index],
                        style: const TextStyle(fontSize: 13),
                      ),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide(color: Colors.green.shade300, width: 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      avatar: Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      onPressed: () => _sendMessage(_suggestions[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: msg.isUser
          ? _buildUserMessage(msg)
          : _buildBotMessage(msg),
    );
  }

  Widget _buildUserMessage(ChatMessage msg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38ef7d).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              msg.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.green.shade100,
          child: Text(
            widget.userName[0].toUpperCase(),
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotMessage(ChatMessage msg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade100,
          child: Icon(
            Icons.smart_toy,
            size: 20,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: MarkdownBody(
                  data: msg.response,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    strong: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    em: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                    h1: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    h2: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    h3: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    listBullet: TextStyle(
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Text(
                      DateFormat('h:mm a').format(msg.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    
                    if (msg.id != null) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => FeedbackDialog(
                              messageId: msg.id!,
                              userId: widget.userId,
                              userRole: widget.userRole,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_outline,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Rate',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade100,
          child: Icon(
            Icons.smart_toy,
            size: 20,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypingDot(0),
              const SizedBox(width: 5),
              _buildTypingDot(1),
              const SizedBox(width: 5),
              _buildTypingDot(2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        final scale = 0.6 + (animValue * 0.4);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade500,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: _isListening 
                    ? Colors.red.shade50 
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    key: ValueKey(_isListening),
                    color: _isListening ? Colors.red : Colors.green,
                  ),
                ),
                onPressed: _listen,
                tooltip: _isListening ? 'Stop Recording' : 'Voice Input',
              ),
            ),
            const SizedBox(width: 8),
            
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _textFieldFocus.hasFocus
                        ? const Color(0xFF38ef7d)
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _textFieldFocus,
                  decoration: const InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: TextStyle(fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _sendMessage,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 0.9).animate(
                CurvedAnimation(
                  parent: _messageSendAnimController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38ef7d).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () => _sendMessage(_controller.text),
                  tooltip: 'Send Message',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _suggestionsScrollController.dispose();
    _textFieldFocus.dispose();
    _suggestionsAnimController.dispose();
    _welcomeAnimController.dispose();
    _messageSendAnimController.dispose();
    
    // Stop speech recognition before disposing
    if (_speech.isListening) {
      _speech.stop();
    }
    
    super.dispose();
  }
}