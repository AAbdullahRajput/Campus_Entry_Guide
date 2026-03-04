require('dotenv').config();
const mysql = require('mysql2');
const fs = require('fs');

const db = mysql.createConnection({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: {
    rejectUnauthorized: false
  },
  multipleStatements: true
});

console.log('📥 Starting database import...');

// Read SQL file
const sqlFile = fs.readFileSync('campus entry guide.sql', 'utf8');

// Remove database creation commands
let sql = sqlFile.replace(/CREATE DATABASE[^;]*;/gi, '');
sql = sql.replace(/USE\s+`[^`]+`;/gi, '');

// Add SET statement at the beginning to disable primary key requirement
sql = 'SET SESSION sql_require_primary_key = 0;\n' + sql;

db.connect((err) => {
  if (err) {
    console.error('❌ Connection failed:', err.message);
    process.exit(1);
  }
  
  console.log('✅ Connected to Aiven MySQL');
  console.log('🔄 Importing SQL file (this may take 30-60 seconds)...');
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Import error:', err.message);
      db.end();
      process.exit(1);
    }
    
    console.log('✅ Import completed!');
    
    // Verify import
    db.query('SHOW TABLES', (err, tables) => {
      if (err) {
        console.error('❌ Cannot verify:', err);
      } else {
        console.log(`\n✅ Database now has ${tables.length} tables:`);
        tables.forEach((table, i) => {
          console.log(`   ${i + 1}. ${Object.values(table)[0]}`);
        });
      }
      
      // Count records in key tables
      db.query('SELECT COUNT(*) as count FROM admin_registration', (err, result) => {
        if (!err) {
          console.log(`\n📊 Sample data check:`);
          console.log(`   Admins: ${result[0].count}`);
        }
        
        db.end();
        console.log('\n🎉 SUCCESS! Your database is ready!');
        console.log('💡 Now run: node server.js');
        console.log('🚀 Your Flutter app should work perfectly!\n');
      });
    });
  });
});