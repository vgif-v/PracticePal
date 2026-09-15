import 'student.dart';
import '../services/class_service.dart';

class DemoData {
  DemoData._();

  static ClassModel getRegielouClass({
    String trainerName = "Coach Regielou",
    String trainerId = "",
  }) {
    return ClassModel(
      id: 'regielou-class-1',
      name: "Regielou's Class",
      joinCode: 'PP-7821',
      trainerId: trainerId,
      trainerName: trainerName,
      schedule: 'Mon & Wed • 4:30 PM',
      room: 'Studio A (Main Mirror)',
      students: [
        StudentData(
          name: 'Bella Minguito',
          age: 13,
          address: '742 Sunflower St., Green Valley',
          trainerName: trainerName,
          cycleNumber: 1,
          sessions: [
            SessionItem(date: 'Oct 02', isCompleted: true),
            SessionItem(date: 'Oct 05', isCompleted: true),
            SessionItem(date: 'Oct 09', isCompleted: true),
            SessionItem(date: 'Oct 12', isCompleted: true),
            SessionItem(date: 'Oct 16', isCompleted: true),
            SessionItem(date: 'Oct 19', isCompleted: true),
            SessionItem(date: 'Oct 23', isCompleted: false),
            SessionItem(date: 'Oct 26', isCompleted: false),
          ],
          payments: const [
            PaymentDueItem(
              label: 'Cycle #1 Tuition',
              amount: '\$140',
              dueDate: 'Paid in Full',
              isPaid: true,
            ),
          ],
        ),
        StudentData(
          name: 'Margareth Caga',
          age: 14,
          address: '128 Blossom Hill, Riverdale',
          trainerName: trainerName,
          cycleNumber: 1,
          sessions: [
            SessionItem(date: 'Oct 02', isCompleted: true),
            SessionItem(date: 'Oct 05', isCompleted: true),
            SessionItem(date: 'Oct 09', isCompleted: true),
            SessionItem(date: 'Oct 12', isCompleted: true),
            SessionItem(date: 'Oct 16', isCompleted: true),
            SessionItem(date: 'Oct 19', isCompleted: false),
            SessionItem(date: 'Oct 23', isCompleted: false),
            SessionItem(date: 'Oct 26', isCompleted: false),
          ],
          payments: const [
            PaymentDueItem(
              label: 'Cycle #1 Tuition',
              amount: '\$140',
              dueDate: 'Due: Oct 28',
              isUrgent: true,
              isPaid: false,
            ),
          ],
        ),
        StudentData(
          name: 'Caeli Alexa',
          age: 12,
          address: '45 Sunset Blvd, Metro City',
          trainerName: trainerName,
          cycleNumber: 1,
          sessions: [
            SessionItem(date: 'Oct 02', isCompleted: true),
            SessionItem(date: 'Oct 05', isCompleted: true),
            SessionItem(date: 'Oct 09', isCompleted: true),
            SessionItem(date: 'Oct 12', isCompleted: true),
            SessionItem(date: 'Oct 16', isCompleted: true),
            SessionItem(date: 'Oct 19', isCompleted: true),
            SessionItem(date: 'Oct 23', isCompleted: true),
            SessionItem(date: 'Oct 26', isCompleted: false),
          ],
          payments: const [
            PaymentDueItem(
              label: 'Cycle #1 Tuition',
              amount: '\$140',
              dueDate: 'Paid in Full',
              isPaid: true,
            ),
          ],
        ),
        StudentData(
          name: 'Joshua Delgado',
          age: 15,
          address: '89 Pine Ridge Way, Oakville',
          trainerName: trainerName,
          cycleNumber: 1,
          sessions: [
            SessionItem(date: 'Oct 02', isCompleted: true),
            SessionItem(date: 'Oct 05', isCompleted: true),
            SessionItem(date: 'Oct 09', isCompleted: true),
            SessionItem(date: 'Oct 12', isCompleted: true),
            SessionItem(date: 'Oct 16', isCompleted: false),
            SessionItem(date: 'Oct 19', isCompleted: false),
            SessionItem(date: 'Oct 23', isCompleted: false),
            SessionItem(date: 'Oct 26', isCompleted: false),
          ],
          payments: const [
            PaymentDueItem(
              label: 'Cycle #1 Tuition',
              amount: '\$140',
              dueDate: 'Due: Oct 30',
              isUrgent: true,
              isPaid: false,
            ),
          ],
        ),
        StudentData(
          name: 'Jillian Remoreras',
          age: 13,
          address: '210 Maple Avenue, Sunnyvale',
          trainerName: trainerName,
          cycleNumber: 1,
          sessions: [
            SessionItem(date: 'Oct 02', isCompleted: true),
            SessionItem(date: 'Oct 05', isCompleted: true),
            SessionItem(date: 'Oct 09', isCompleted: true),
            SessionItem(date: 'Oct 12', isCompleted: true),
            SessionItem(date: 'Oct 16', isCompleted: true),
            SessionItem(date: 'Oct 19', isCompleted: true),
            SessionItem(date: 'Oct 23', isCompleted: true),
            SessionItem(date: 'Oct 26', isCompleted: true),
          ],
          payments: const [
            PaymentDueItem(
              label: 'Cycle #1 Tuition',
              amount: '\$140',
              dueDate: 'Paid in Full',
              isPaid: true,
            ),
          ],
        ),
      ],
    );
  }
}
