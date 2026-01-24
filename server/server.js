// ================= IMPORTS =================
const express = require("express");
const mysql = require("mysql2");
const bcrypt = require("bcrypt");
const bodyParser = require("body-parser");
const cors = require("cors");
const nodemailer = require("nodemailer");
const twilio = require("twilio");

// ================= APP SETUP =================
const app = express();
app.use(cors());
app.use(bodyParser.json());

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(express.raw({ limit: '50mb' }));
app.use(express.text({ limit: '50mb' }));

// Add this right after app.use(bodyParser.json());
app.get('/', (req, res) => {
  res.json({ message: 'Server is running!' });
});

// ================= MYSQL CONNECTION =================
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "campus entry guide",
});

db.connect((err) => {
  if (err) {
    console.error("❌ MySQL Connection Error:", err);
    return;
  }
  console.log("✅ MySQL Connected!");
});

// ================= HELPER FUNCTIONS =================
const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(10);
  return await bcrypt.hash(password, salt);
};

const generateOtp = () => Math.floor(100000 + Math.random() * 900000).toString();

const getTableByRole = (role) => {
  if (role === "Student") return "student_registration";
  if (role === "Teacher") return "teacher_registration";
  if (role === "Admin") return "admin_registration";
  return null;
};

// ================= EMAIL TRANSPORTER =================
const mailTransporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "qabqbdul@gmail.com",
    pass: "ivfk gjss xzuc wfix",
  },
});


const checkEmailExists = (email) => {
  const tables = [
    "student_registration",
    "teacher_registration",
    "admin_registration"
  ];

  return new Promise((resolve, reject) => {
    let found = false;
    let checked = 0;

    tables.forEach((table) => {
      db.query(`SELECT * FROM ${table} WHERE email=? LIMIT 1`, [email], (err, results) => {
        checked++;
        if (err) return reject(err);

        if (results.length > 0) {
          found = true;
        }

        if (checked === tables.length) {
          resolve(found);
        }
      });
    });
  });
};


// ================= REGISTER ENDPOINT =================
app.post("/register", async (req, res) => {
  const { role, full_name, email, password } = req.body;

  if (!role || !full_name || !email || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  try {
    // ✅ Check if email already exists in any table
    const exists = await checkEmailExists(email);
    if (exists) {
      return res.status(400).json({ message: "Email already exists. Please use a different email." });
    }

    const hashedPassword = await hashPassword(password);

    let sql, values;

    if (role === "Student") {
      const arid_no = req.body.arid_no || null;
      const degree = req.body.degree || null;
      const semester_no = req.body.semester_no || null;
      const section = req.body.section || null;
      const phone_number = req.body.phone_number || null;

      sql = `INSERT INTO student_registration
             (full_name, arid_no, degree, semester_no, section, email, phone_number, password)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
      values = [full_name, arid_no, degree, semester_no, section, email, phone_number, hashedPassword];

    } else if (role === "Teacher") {
      const department = req.body.department || null;
      const subject_name = req.body.subject_name || null;
      const shift = req.body.shift || null;
      const phone_number = req.body.phone_number || null;

      sql = `INSERT INTO teacher_registration
             (full_name, department, subject_name, shift, email, phone_number, password)
             VALUES (?, ?, ?, ?, ?, ?, ?)`;
      values = [full_name, department, subject_name, shift, email, phone_number, hashedPassword];

    } else if (role === "Admin") {
      const department = req.body.department || null;
      const admin_id = req.body.admin_id || null;
      const office_name = req.body.office_name || null;
      const phone_number = req.body.phone_number || null;

      sql = `INSERT INTO admin_registration
             (full_name, department, admin_id, office_name, email, phone_number, password)
             VALUES (?, ?, ?, ?, ?, ?, ?)`;
      values = [full_name, department, admin_id, office_name, email, phone_number, hashedPassword];

    } else {
      return res.status(400).json({ message: "Invalid role" });
    }

    db.query(sql, values, (err, result) => {
      if (err) {
        console.error("Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }
      return res.status(201).json({ message: `${role} registered successfully!` });
    });
  } catch (error) {
    console.error("Server Error:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

// ================= LOGIN ENDPOINT =================
app.post("/login", async (req, res) => {
  const { role, email, password } = req.body;

  if (!role || !email || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  let table;
  if (role === "Student") table = "student_registration";
  else if (role === "Teacher") table = "teacher_registration";
  else if (role === "Admin") table = "admin_registration";
  else return res.status(400).json({ message: "Invalid role" });

  const sql = `SELECT * FROM ${table} WHERE email = ? LIMIT 1`;
  db.query(sql, [email], async (err, results) => {
    if (err) {
      console.error("Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(401).json({ message: "Email not found" });
    }

    const user = results[0];
    const match = await bcrypt.compare(password, user.password);

    if (!match) {
      return res.status(401).json({ message: "Incorrect password" });
    }

    // ✅ Build complete user response based on role
    let userResponse = {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      role: role,
      phone_number: user.phone_number || null,
    };

    // ✅ Add role-specific fields
    if (role === "Student") {
      userResponse.arid_no = user.arid_no || null;
      userResponse.degree = user.degree || null;
      userResponse.semester_no = user.semester_no || null;
      userResponse.section = user.section || null;
    } else if (role === "Teacher") {
      userResponse.department = user.department || null;
      userResponse.subject_name = user.subject_name || null;
      userResponse.shift = user.shift || null;
    } else if (role === "Admin") {
      userResponse.department = user.department || null;
      userResponse.admin_id = user.admin_id || null;
      userResponse.office_name = user.office_name || null;
    }

    console.log(`✅ ${role} logged in:`, userResponse);

    return res.status(200).json({
      message: `${role} logged in successfully`,
      user: userResponse,
    });
  });
});

// ================= UPDATE USER PROFILE ENDPOINT (ADD THIS TO YOUR SERVER.JS) =================
app.post("/update-user-profile", async (req, res) => {
  const { userId, role } = req.body;

  console.log("📝 Profile Update Request - User ID:", userId, "Role:", role);

  if (!userId || !role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const table = getTableByRole(role);
  if (!table) {
    return res.status(400).json({ message: "Invalid role" });
  }

  try {
    // Common fields
    let updateFields = [];
    let updateValues = [];

    // Full Name
    if (req.body.full_name) {
      updateFields.push("full_name = ?");
      updateValues.push(req.body.full_name);
    }

    // Phone Number
    if (req.body.phone_number) {
      updateFields.push("phone_number = ?");
      updateValues.push(req.body.phone_number);
    }

    // Department
    if (req.body.department) {
      updateFields.push("department = ?");
      updateValues.push(req.body.department);
    }

    // Profile Image
    if (req.body.profile_image !== undefined) {
      updateFields.push("profile_image = ?");
      updateValues.push(req.body.profile_image);
    }

    // Role-specific fields
    if (role === "Student") {
      if (req.body.arid_no) {
        updateFields.push("arid_no = ?");
        updateValues.push(req.body.arid_no);
      }
      if (req.body.degree) {
        updateFields.push("degree = ?");
        updateValues.push(req.body.degree);
      }
      if (req.body.semester_no) {
        updateFields.push("semester_no = ?");
        updateValues.push(req.body.semester_no);
      }
      if (req.body.section) {
        updateFields.push("section = ?");
        updateValues.push(req.body.section);
      }
    } else if (role === "Teacher") {
      if (req.body.subject_name) {
        updateFields.push("subject_name = ?");
        updateValues.push(req.body.subject_name);
      }
      if (req.body.shift) {
        updateFields.push("shift = ?");
        updateValues.push(req.body.shift);
      }
    } else if (role === "Admin") {
      if (req.body.admin_id) {
        updateFields.push("admin_id = ?");
        updateValues.push(req.body.admin_id);
      }
      if (req.body.office_name) {
        updateFields.push("office_name = ?");
        updateValues.push(req.body.office_name);
      }
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    // Add userId to the end for WHERE clause
    updateValues.push(userId);

    const sql = `UPDATE ${table} SET ${updateFields.join(", ")} WHERE id = ?`;

    console.log("🔄 SQL Query:", sql);
    console.log("🔄 Values:", updateValues);

    db.query(sql, updateValues, (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      if (result.affectedRows === 0) {
        console.log("❌ User not found for ID:", userId);
        return res.status(404).json({ message: "User not found" });
      }

      console.log("✅ Profile updated successfully for User ID:", userId);

      res.status(200).json({
        message: "Profile updated successfully",
        affectedRows: result.affectedRows,
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// ================= ALSO UPDATE THE GET PROFILE ENDPOINT TO INCLUDE profile_image =================
// Replace your existing /get-user-profile endpoint with this updated version:

app.post("/get-user-profile", (req, res) => {
  const { userId, role } = req.body;

  console.log("📋 Profile Request - User ID:", userId, "Role:", role);

  if (!userId || !role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const table = getTableByRole(role);
  if (!table) {
    return res.status(400).json({ message: "Invalid role" });
  }

  const sql = `SELECT * FROM ${table} WHERE id = ? LIMIT 1`;
  
  db.query(sql, [userId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      console.log("❌ User not found for ID:", userId);
      return res.status(404).json({ message: "User not found" });
    }

    const user = results[0];
    console.log("✅ User found:", user.full_name);

    // Remove sensitive data
    delete user.password;
    delete user.otp;
    delete user.otp_expiry;

    // Format response based on role
    let profileData = {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone_number: user.phone_number || "Not provided",
      role: role,
      profile_image: user.profile_image || null, // ← Added this line
    };

    if (role === "Student") {
      profileData.arid_no = user.arid_no || "Not assigned";
      profileData.degree = user.degree || "Not assigned";
      profileData.semester = user.semester_no || "Not assigned";
      profileData.section = user.section || "Not assigned";
      // profileData.department = user.degree || "Not assigned";
    } else if (role === "Teacher") {
      profileData.department = user.department || "Not assigned";
      profileData.subject_name = user.subject_name || "Not assigned";
      profileData.shift = user.shift || "Not assigned";
    } else if (role === "Admin") {
      profileData.department = user.department || "Not assigned";
      profileData.admin_id = user.admin_id || "Not assigned";
      profileData.office_name = user.office_name || "Not assigned";
    }

    res.status(200).json({
      message: "Profile retrieved successfully",
      userData: profileData
    });
  });
});

// ================= CHANGE PASSWORD ENDPOINT =================
app.post("/change-password", async (req, res) => {
  const { userId, role, email, currentPassword, newPassword } = req.body;

  console.log("🔐 Change Password Request - User ID:", userId, "Role:", role);

  if (!userId || !role || !email || !currentPassword || !newPassword) {
    return res.status(400).json({ message: "All fields are required" });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ message: "New password must be at least 6 characters" });
  }

  const table = getTableByRole(role);
  if (!table) {
    return res.status(400).json({ message: "Invalid role" });
  }

  try {
    // Get user from database
    const sql = `SELECT * FROM ${table} WHERE id = ? AND email = ? LIMIT 1`;
    
    db.query(sql, [userId, email], async (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      if (results.length === 0) {
        console.log("❌ User not found for ID:", userId);
        return res.status(404).json({ message: "User not found" });
      }

      const user = results[0];

      // Verify current password
      const match = await bcrypt.compare(currentPassword, user.password);
      if (!match) {
        console.log("❌ Current password is incorrect");
        return res.status(401).json({ message: "Current password is incorrect" });
      }

      // Hash new password
      const hashedNewPassword = await hashPassword(newPassword);

      // Update password in database
      const updateSql = `UPDATE ${table} SET password = ? WHERE id = ?`;
      
      db.query(updateSql, [hashedNewPassword, userId], (updateErr, updateResult) => {
        if (updateErr) {
          console.error("❌ Failed to update password:", updateErr);
          return res.status(500).json({ message: "Failed to update password" });
        }

        if (updateResult.affectedRows === 0) {
          return res.status(404).json({ message: "Failed to update password" });
        }

        console.log("✅ Password changed successfully for User ID:", userId);

        // Send email notification
        const mailOptions = {
          to: email,
          subject: "Password Changed Successfully - Campus Entry Guide",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">✅ Password Changed Successfully!</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${user.full_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  Your password has been changed successfully. If you did not make this change, please contact support immediately.
                </p>
                
                <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <p style="color: #2e7d32; margin: 0;"><strong>Account:</strong> ${email}</p>
                  <p style="color: #2e7d32; margin: 0;"><strong>Role:</strong> ${role}</p>
                  <p style="color: #2e7d32; margin: 0;"><strong>Changed on:</strong> ${new Date().toLocaleString()}</p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr, info) => {
          if (mailErr) {
            console.error("⚠️ Failed to send password change email:", mailErr);
          } else {
            console.log("✅ Password change email sent to:", email);
          }
        });

        res.status(200).json({
          message: "Password changed successfully",
        });
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// ================= GOOGLE LOGIN - CHECK EMAIL & SEND OTP =================
app.post("/google-check-email", async (req, res) => {
  const { email } = req.body;
  
  if (!email) {
    return res.status(400).json({ message: "Email is required" });
  }

  const tables = [
    { name: "student_registration", role: "Student" },
    { name: "teacher_registration", role: "Teacher" },
    { name: "admin_registration", role: "Admin" }
  ];

  let foundUser = null;
  let userRole = null;
  let tableName = null;

  // Check if user exists in any table
  for (const table of tables) {
    const sqlCheck = `SELECT * FROM ${table.name} WHERE email = ? LIMIT 1`;
    const results = await new Promise((resolve) =>
      db.query(sqlCheck, [email], (err, results) => {
        if (err) return resolve([]);
        resolve(results);
      })
    );

    if (results.length > 0) {
      foundUser = results[0];
      userRole = table.role;
      tableName = table.name;
      break;
    }
  }

  // If user not found in any table
  if (!foundUser) {
    return res.status(404).json({ 
      message: "Email not found. Please register first.",
      found: false
    });
  }

  // Generate OTP and send to email
  const otp = generateOtp();
  const expiry = Date.now() + 5 * 60 * 1000; // 5 minutes

  console.log(`✅ Generated OTP for ${email}: ${otp}`);

  // Update OTP in database
  const updateSql = `UPDATE ${tableName} SET otp=?, otp_expiry=? WHERE email=?`;
  db.query(updateSql, [otp, expiry, email], (dbErr) => {
    if (dbErr) {
      console.error("❌ Failed to save OTP:", dbErr);
      return res.status(500).json({ message: "Failed to generate OTP" });
    }

    // Send OTP email
    const mailOptions = {
      to: email,
      subject: "Google Sign-In Verification - Campus Entry Guide",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
          <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
            </div>
            
            <h2 style="color: #333; margin-bottom: 20px;">🔐 Google Sign-In Verification</h2>
            
            <p style="color: #666; font-size: 16px; line-height: 1.6;">
              Hello ${foundUser.full_name},
            </p>
            
            <p style="color: #666; font-size: 16px; line-height: 1.6;">
              You are attempting to sign in with Google. Please use the verification code below to complete your login:
            </p>
            
            <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 25px; text-align: center; border-radius: 8px; margin: 30px 0;">
              <div style="font-size: 42px; font-weight: bold; color: white; letter-spacing: 12px; font-family: 'Courier New', monospace;">
                ${otp}
              </div>
            </div>
            
            <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                <strong>Account Details:</strong><br>
                Email: ${email}<br>
                Role: ${userRole}
              </p>
            </div>
            
            <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #856404; margin: 0; font-size: 14px;">
                ⏰ This code will expire in <strong>5 minutes</strong>
              </p>
            </div>
            
            <p style="color: #999; font-size: 13px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              If you didn't request this code, please ignore this email or contact support if you have concerns.
            </p>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #999; font-size: 12px; margin: 0;">
                © 2025 Campus Entry Guide. All rights reserved.
              </p>
            </div>
          </div>
        </div>
      `,
    };

    mailTransporter.sendMail(mailOptions, (mailErr, info) => {
      if (mailErr) {
        console.error("❌ Email Error:", mailErr);
        return res.status(500).json({ message: "Failed to send OTP email" });
      }

      console.log("✅ OTP email sent:", info.response);
      res.json({ 
        message: "OTP sent to your email",
        found: true,
        role: userRole,
        fullName: foundUser.full_name
      });
    });
  });
});

// ================= GOOGLE LOGIN - VERIFY OTP =================
app.post("/google-verify-otp", async (req, res) => {
  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ message: "Email and OTP are required" });
  }

  const tables = [
    { name: "student_registration", role: "Student" },
    { name: "teacher_registration", role: "Teacher" },
    { name: "admin_registration", role: "Admin" }
  ];

  let foundUser = null;
  let userRole = null;
  let tableName = null;

  // Find user in tables
  for (const table of tables) {
    const sqlCheck = `SELECT * FROM ${table.name} WHERE email = ? LIMIT 1`;
    const results = await new Promise((resolve) =>
      db.query(sqlCheck, [email], (err, results) => {
        if (err) return resolve([]);
        resolve(results);
      })
    );

    if (results.length > 0) {
      foundUser = results[0];
      userRole = table.role;
      tableName = table.name;
      break;
    }
  }

  if (!foundUser) {
    return res.status(404).json({ message: "User not found" });
  }

  console.log("🔍 Stored OTP:", foundUser.otp, "| Provided OTP:", otp);
  console.log("🔍 OTP Expiry:", foundUser.otp_expiry, "| Current Time:", Date.now());

  // Verify OTP
  if (foundUser.otp !== otp) {
    return res.status(400).json({ message: "Invalid OTP" });
  }

  if (Date.now() > foundUser.otp_expiry) {
    return res.status(400).json({ message: "OTP has expired" });
  }

  // Generate default password
  const defaultPassword = Math.floor(100000 + Math.random() * 900000).toString();
  const hashedPassword = await hashPassword(defaultPassword);

  // Update password and clear OTP
  const updateSql = `UPDATE ${tableName} SET password=?, otp=NULL, otp_expiry=NULL WHERE email=?`;
  db.query(updateSql, [hashedPassword, email], (updateErr) => {
    if (updateErr) {
      console.error("❌ Failed to update password:", updateErr);
      return res.status(500).json({ message: "Failed to update password" });
    }

    // Send password email
    const passwordMailOptions = {
      to: email,
      subject: "Your New Login Password - Campus Entry Guide",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
          <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
            </div>
            
            <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
              <h2 style="color: white; margin: 0;">✅ Login Successful!</h2>
            </div>
            
            <h3 style="color: #333; margin-bottom: 15px;">Hi ${foundUser.full_name},</h3>
            
            <p style="color: #666; font-size: 16px; line-height: 1.6;">
              You have successfully logged in with Google. Your default password for future logins has been set.
            </p>
            
            <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
              <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Your Login Credentials:</h4>
              <p style="color: #1b5e20; margin: 5px 0;"><strong>Email:</strong> ${email}</p>
              <p style="color: #1b5e20; margin: 5px 0;"><strong>Role:</strong> ${userRole}</p>
              <p style="color: #1b5e20; margin: 5px 0;"><strong>Default Password:</strong> <span style="font-size: 24px; font-weight: bold; font-family: 'Courier New', monospace;">${defaultPassword}</span></p>
            </div>
            
            <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #856404; margin: 0; font-size: 14px;">
                <strong>⚠️ Security Note:</strong><br>
                Please save this password in a secure location. You can use this password for future logins or continue using Google Sign-In.
              </p>
            </div>
            
            <p style="color: #666; font-size: 14px; line-height: 1.6; margin-top: 30px;">
              <strong>Security Tips:</strong><br>
              • Keep your password confidential<br>
              • You can change this password anytime from your profile<br>
              • Use Google Sign-In for faster access<br>
            </p>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #999; font-size: 12px; margin: 0;">
                © 2025 Campus Entry Guide. All rights reserved.
              </p>
            </div>
          </div>
        </div>
      `,
    };

    mailTransporter.sendMail(passwordMailOptions, (mailErr, info) => {
      if (mailErr) {
        console.error("⚠️ Failed to send password email:", mailErr);
      } else {
        console.log("✅ Password email sent to:", email);
      }
    });

    console.log("✅ Google OTP verified successfully for:", email);

    res.json({
      message: "Login success",
      user: {
        id: foundUser.id,
        full_name: foundUser.full_name,
        email: foundUser.email,
        role: userRole,
        phone_number: foundUser.phone_number || null,
      },
    });
  });
});

// ================= EMAIL OTP ENDPOINTS (FORGET PASSWORD) =================
app.post("/send-email-otp", (req, res) => {
  console.log("📧 Email OTP Request:", req.body);
  
  const { email, role } = req.body;
  const table = getTableByRole(role);
  
  if (!email || !table) {
    console.log("❌ Invalid request - missing email or role");
    return res.status(400).json({ message: "Invalid request" });
  }

  db.query(
    `SELECT * FROM ${table} WHERE email=? LIMIT 1`,
    [email],
    (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error" });
      }

      if (results.length === 0) {
        console.log("❌ Email not found:", email);
        return res.status(404).json({ message: "Email not found in database" });
      }

      const otp = generateOtp();
      const expiry = Date.now() + 60 * 1000;

      console.log(`✅ Generated OTP for ${email}: ${otp}`);

      db.query(
        `UPDATE ${table} SET otp=?, otp_expiry=? WHERE email=?`,
        [otp, expiry, email],
        (dbErr) => {
          if (dbErr) {
            console.error("❌ Failed to save OTP:", dbErr);
            return res.status(500).json({ message: "Failed to generate OTP" });
          }

          const mailOptions = {
            to: email,
            subject: "OTP Verification - Campus Entry Guide",
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
                <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                  <div style="text-align: center; margin-bottom: 30px;">
                    <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
                  </div>
                  
                  <h2 style="color: #333; margin-bottom: 20px;">Verification Code</h2>
                  
                  <p style="color: #666; font-size: 16px; line-height: 1.6;">
                    Hello! You have requested to reset your password. Please use the verification code below:
                  </p>
                  
                  <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 25px; text-align: center; border-radius: 8px; margin: 30px 0;">
                    <div style="font-size: 42px; font-weight: bold; color: white; letter-spacing: 12px; font-family: 'Courier New', monospace;">
                      ${otp}
                    </div>
                  </div>
                  
                  <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
                    <p style="color: #856404; margin: 0; font-size: 14px;">
                      ⏰ This code will expire in <strong>1 minute</strong>
                    </p>
                  </div>
                  
                  <p style="color: #999; font-size: 13px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                    If you didn't request this code, please ignore this email or contact support if you have concerns.
                  </p>
                  
                  <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                    <p style="color: #999; font-size: 12px; margin: 0;">
                      © 2025 Campus Entry Guide. All rights reserved.
                    </p>
                  </div>
                </div>
              </div>
            `,
          };

          mailTransporter.sendMail(mailOptions, (mailErr, info) => {
            if (mailErr) {
              console.error("❌ Email Error:", mailErr);
              return res.status(500).json({ message: "Failed to send OTP email" });
            }

            console.log("✅ Email sent:", info.response);
            res.json({ message: "OTP sent to email" });
          });
        }
      );
    }
  );
});

app.post("/verify-email-otp", (req, res) => {
  console.log("🔍 Verify Email OTP Request:", req.body);
  
  const { email, otp, role } = req.body;
  const table = getTableByRole(role);

  if (!email || !otp || !table) {
    console.log("❌ Invalid request - missing parameters");
    return res.status(400).json({ message: "Invalid request" });
  }

  db.query(
    `SELECT * FROM ${table} WHERE email=? LIMIT 1`,
    [email],
    (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error" });
      }

      if (results.length === 0) {
        console.log("❌ Email not found:", email);
        return res.status(404).json({ message: "Email not found" });
      }

      const user = results[0];

      console.log("🔍 Stored OTP:", user.otp, "| Provided OTP:", otp);
      console.log("🔍 OTP Expiry:", user.otp_expiry, "| Current Time:", Date.now());

      if (user.otp !== otp) {
        console.log("❌ Invalid OTP");
        return res.status(400).json({ message: "Invalid OTP" });
      }

      if (Date.now() > user.otp_expiry) {
        console.log("❌ OTP expired");
        return res.status(400).json({ message: "OTP has expired" });
      }

      db.query(
        `UPDATE ${table} SET otp=NULL, otp_expiry=NULL WHERE email=?`,
        [email],
        (clearErr) => {
          if (clearErr) {
            console.error("⚠️ Error clearing OTP:", clearErr);
          }
        }
      );

      console.log("✅ OTP verified successfully for:", email);

      res.json({
        message: "Login success",
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          role,
          phone_number: user.phone_number || null,
        },
      });
    }
  );
});


// ================= UPDATE ANNOUNCEMENTS TABLE =================
// Run this SQL to add the new columns:

// ================= UPDATED CREATE ANNOUNCEMENT =================
// ================= CREATE ANNOUNCEMENT =================
app.post("/create-announcement", (req, res) => {
  const { title, description, category, target_role, image_url, created_by } = req.body;

  if (!title || !description || !category || !created_by) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const sql = `
    INSERT INTO announcements 
    (title, description, category, target_role, image_url, created_by, created_at, updated_at, is_active)
    VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW(), 1)
  `;

  const values = [
    title,
    description,
    category,
    target_role || 'all',
    image_url || null,
    created_by
  ];

  db.query(sql, values, (err, result) => {
    if (err) {
      console.error("❌ Error creating announcement:", err);
      return res.status(500).json({ message: "Failed to create announcement", error: err });
    }

    console.log(`✅ Announcement created with ID: ${result.insertId} by admin ${created_by}`);
    res.status(201).json({
      message: "Announcement created successfully",
      announcementId: result.insertId,
    });
  });
});
// ================= GET ADMIN ANNOUNCEMENTS WITH PROFILE IMAGE =================
app.post("/get-admin-announcements", (req, res) => {
  const { created_by } = req.body;

  if (!created_by) {
    return res.status(400).json({ message: "Admin ID is required" });
  }

  const sql = `
    SELECT 
      a.*,
      a.created_by_name,
      ar.profile_image as admin_profile_image
    FROM announcements a
    LEFT JOIN admin_registration ar ON a.created_by = ar.id
    WHERE a.created_by = ?
    ORDER BY a.created_at DESC
  `;

  db.query(sql, [created_by], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch announcements", error: err });
    }

    console.log(`✅ Fetched ${results.length} announcements for admin with profile images`);

    res.status(200).json({
      message: "Announcements fetched successfully",
      announcements: results,
    });
  });
});

// ================= GET ALL ANNOUNCEMENTS (ALL ADMINS) =================
app.post("/get-all-announcements", (req, res) => {
  const sql = `
    SELECT 
      a.id,
      a.title,
      a.description,
      a.category,
      a.target_role,
      a.image_url,
      a.created_at,
      a.updated_at,
      a.is_active,
      a.created_by,
      ar.full_name as created_by_name,
      ar.profile_image as admin_profile_image
    FROM announcements a
    LEFT JOIN admin_registration ar ON a.created_by = ar.id
    ORDER BY a.created_at DESC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch announcements", error: err });
    }

    console.log(`✅ Fetched ${results.length} announcements from all admins`);
    
    // Log which admins have posts
    const adminCounts = {};
    results.forEach(r => {
      adminCounts[r.created_by_name] = (adminCounts[r.created_by_name] || 0) + 1;
    });
    console.log("📊 Announcements per admin:", adminCounts);

    res.status(200).json({
      message: "Announcements fetched successfully",
      announcements: results,
    });
  });
});

// ================= GET USER NOTIFICATIONS WITH READ STATUS (FIXED) =================
app.post("/get-user-notifications", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  console.log(`📬 Fetching notifications for User ID: ${userId}, Role: ${userRole}`);

  // ✅ FIX: Normalize role to handle singular/plural
  const normalizedRole = userRole.toLowerCase();
  const targetRole = normalizedRole === 'teacher' ? 'teachers' : 
                     normalizedRole === 'student' ? 'students' : 
                     normalizedRole;

  let sql;
  let queryParams;

  if (normalizedRole === 'admin') {
    // Admin sees ALL announcements
    sql = `
      SELECT 
        a.id,
        a.title,
        a.description,
        a.category,
        a.target_role,
        a.image_url,
        a.created_at,
        a.is_active,
        a.created_by,
        ar.full_name as created_by_name,
        ar.profile_image as admin_profile_image,
        COALESCE(anr.is_read, 0) as is_read,
        anr.read_at
      FROM announcements a
      LEFT JOIN admin_registration ar ON a.created_by = ar.id
      LEFT JOIN announcement_reads anr ON a.id = anr.announcement_id 
        AND anr.user_id = ? 
        AND anr.user_role = ?
      WHERE a.is_active = 1
      ORDER BY 
        COALESCE(anr.is_read, 0) ASC,
        a.created_at DESC
    `;
    queryParams = [userId, userRole];
  } else {
    // Teachers and Students see only their role + "all"
    // ✅ FIX: Use normalized plural form for matching
    sql = `
      SELECT 
        a.id,
        a.title,
        a.description,
        a.category,
        a.target_role,
        a.image_url,
        a.created_at,
        a.is_active,
        a.created_by,
        ar.full_name as created_by_name,
        ar.profile_image as admin_profile_image,
        COALESCE(anr.is_read, 0) as is_read,
        anr.read_at
      FROM announcements a
      LEFT JOIN admin_registration ar ON a.created_by = ar.id
      LEFT JOIN announcement_reads anr ON a.id = anr.announcement_id 
        AND anr.user_id = ? 
        AND anr.user_role = ?
      WHERE a.is_active = 1 
        AND (
          LOWER(a.target_role) = 'all' 
          OR LOWER(a.target_role) = ?
        )
      ORDER BY 
        COALESCE(anr.is_read, 0) ASC,
        a.created_at DESC
    `;
    queryParams = [userId, userRole, targetRole];
  }

  db.query(sql, queryParams, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch notifications", error: err });
    }

    const unreadCount = results.filter(n => n.is_read === 0).length;
    
    console.log(`✅ Fetched ${results.length} notifications (${unreadCount} unread) for ${userRole} user ${userId}`);
    console.log(`   Target role used: ${targetRole}`);
    console.log(`   Categories breakdown:`, results.reduce((acc, r) => {
      acc[r.category] = (acc[r.category] || 0) + 1;
      return acc;
    }, {}));

    res.status(200).json({
      message: "Notifications fetched successfully",
      notifications: results,
      unreadCount: unreadCount,
    });
  });
});
// ================= UPDATE ANNOUNCEMENT =================
app.post("/update-announcement", (req, res) => {
  const { id, title, description, category, target_role, image_url, is_active } = req.body;

  if (!id || !title || !description || !category) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  const sql = `
    UPDATE announcements
    SET title = ?, description = ?, category = ?, target_role = ?, image_url = ?, is_active = ?, updated_at = NOW()
    WHERE id = ?
  `;

  db.query(
    sql,
    [title, description, category, target_role || 'all', image_url || null, is_active !== undefined ? is_active : 1, id],
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to update announcement", error: err });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({ message: "Announcement not found" });
      }

      console.log("✅ Announcement updated:", id);

      res.status(200).json({
        message: "Announcement updated successfully",
      });
    }
  );
});

// ================= DELETE ANNOUNCEMENT =================
app.post("/delete-announcement", (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Announcement ID is required" });
  }

  const sql = `DELETE FROM announcements WHERE id = ?`;

  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to delete announcement", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Announcement not found" });
    }

    console.log("✅ Announcement deleted:", id);

    res.status(200).json({
      message: "Announcement deleted successfully",
    });
  });
});

// ================= MARK AS READ =================
app.post("/mark-notification-read", (req, res) => {
  const { announcementId, userId, userRole } = req.body;

  if (!announcementId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  console.log(`📖 Marking notification ${announcementId} as read for user ${userId} (${userRole})`);

  const sql = `
    INSERT INTO announcement_reads (announcement_id, user_id, user_role, is_read, read_at)
    VALUES (?, ?, ?, 1, NOW())
    ON DUPLICATE KEY UPDATE is_read = 1, read_at = NOW()
  `;

  db.query(sql, [announcementId, userId, userRole], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to mark as read", error: err });
    }

    console.log("✅ Notification marked as read:", announcementId);

    res.status(200).json({
      message: "Notification marked as read",
    });
  });
});

// ================= GET UNREAD COUNT =================
app.post("/get-unread-count", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const sql = `
    SELECT COUNT(*) as unreadCount
    FROM announcements a
    LEFT JOIN announcement_reads ar ON a.id = ar.announcement_id AND ar.user_id = ? AND ar.user_role = ?
    WHERE a.is_active = 1 AND (ar.is_read = 0 OR ar.is_read IS NULL)
  `;

  db.query(sql, [userId, userRole], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch unread count", error: err });
    }

    console.log(`✅ Unread count for user ${userId}:`, results[0].unreadCount);

    res.status(200).json({
      message: "Unread count fetched successfully",
      unreadCount: results[0].unreadCount,
    });
  });
});


// ================= FILTER CONFIGURATION ENDPOINTS =================
app.get("/get-filter-options", (req, res) => {
  const sql = `SELECT filter_type, filter_value FROM filter_configurations WHERE is_active = 1`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    const filters = {
      degrees: [],
      sections: [],
      semesters: [],
      departments: [],
      subjects: [],
      shifts: []
    };

    results.forEach(row => {
      if (row.filter_type === 'degree') filters.degrees.push(row.filter_value);
      if (row.filter_type === 'section') filters.sections.push(row.filter_value);
      if (row.filter_type === 'semester') filters.semesters.push(row.filter_value);
      if (row.filter_type === 'department') filters.departments.push(row.filter_value);
      if (row.filter_type === 'subject') filters.subjects.push(row.filter_value);
      if (row.filter_type === 'shift') filters.shifts.push(row.filter_value);
    });

    res.status(200).json(filters);
  });
});

app.post("/add-filter-option", (req, res) => {
  const { filter_type, filter_value } = req.body;

  if (!filter_type || !filter_value) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const sql = `INSERT INTO filter_configurations (filter_type, filter_value) VALUES (?, ?)`;
  
  db.query(sql, [filter_type, filter_value], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(201).json({ message: "Filter option added successfully" });
  });
});

app.post("/delete-filter-option", (req, res) => {
  const { filter_type, filter_value } = req.body;

  if (!filter_type || !filter_value) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const sql = `DELETE FROM filter_configurations WHERE filter_type = ? AND filter_value = ?`;
  
  db.query(sql, [filter_type, filter_value], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(200).json({ message: "Filter option deleted successfully" });
  });
});

// ================= STUDENT MANAGEMENT ENDPOINTS =================
app.get("/get-all-students", (req, res) => {
  const sql = `SELECT id, full_name, email, arid_no, degree, semester_no, section, phone_number, profile_image FROM student_registration ORDER BY full_name ASC`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(200).json({ students: results });
  });
});

app.post("/add-student", async (req, res) => {
  const { full_name, email, arid_no, degree, semester_no, section, phone_number, password } = req.body;

  if (!full_name || !email || !arid_no || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  try {
    const exists = await checkEmailExists(email);
    if (exists) {
      return res.status(400).json({ message: "Email already exists" });
    }

    const hashedPassword = await hashPassword(password);

    const sql = `INSERT INTO student_registration (full_name, email, arid_no, degree, semester_no, section, phone_number, password) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
    
    db.query(sql, [full_name, email, arid_no, degree, semester_no, section, phone_number, hashedPassword], (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      res.status(201).json({ message: "Student added successfully", id: result.insertId });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

app.post("/update-student", (req, res) => {
  const { id, full_name, arid_no, degree, semester_no, section, phone_number } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Student ID is required" });
  }

  const sql = `UPDATE student_registration SET full_name = ?, arid_no = ?, degree = ?, semester_no = ?, section = ?, phone_number = ? WHERE id = ?`;
  
  db.query(sql, [full_name, arid_no, degree, semester_no, section, phone_number, id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Student not found" });
    }

    res.status(200).json({ message: "Student updated successfully" });
  });
});

app.post("/delete-student", (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Student ID is required" });
  }

  const sql = `DELETE FROM student_registration WHERE id = ?`;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Student not found" });
    }

    res.status(200).json({ message: "Student deleted successfully" });
  });
});

// ================= TEACHER MANAGEMENT ENDPOINTS =================
app.get("/get-all-teachers", (req, res) => {
  const sql = `SELECT id, full_name, email, department, subject_name, shift, phone_number, profile_image FROM teacher_registration ORDER BY full_name ASC`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(200).json({ teachers: results });
  });
});

app.post("/add-teacher", async (req, res) => {
  const { full_name, email, department, subject_name, shift, phone_number, password } = req.body;

  if (!full_name || !email || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  try {
    const exists = await checkEmailExists(email);
    if (exists) {
      return res.status(400).json({ message: "Email already exists" });
    }

    const hashedPassword = await hashPassword(password);

    const sql = `INSERT INTO teacher_registration (full_name, email, department, subject_name, shift, phone_number, password) VALUES (?, ?, ?, ?, ?, ?, ?)`;
    
    db.query(sql, [full_name, email, department, subject_name, shift, phone_number, hashedPassword], (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      res.status(201).json({ message: "Teacher added successfully", id: result.insertId });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

app.post("/update-teacher", (req, res) => {
  const { id, full_name, department, subject_name, shift, phone_number } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  const sql = `UPDATE teacher_registration SET full_name = ?, department = ?, subject_name = ?, shift = ?, phone_number = ? WHERE id = ?`;
  
  db.query(sql, [full_name, department, subject_name, shift, phone_number, id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Teacher not found" });
    }

    res.status(200).json({ message: "Teacher updated successfully" });
  });
});

app.post("/delete-teacher", (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  const sql = `DELETE FROM teacher_registration WHERE id = ?`;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Teacher not found" });
    }

    res.status(200).json({ message: "Teacher deleted successfully" });
  });
});



// ================= LOST & FOUND ENDPOINTS =================

// 📍 CATEGORIES & LOCATIONS CONSTANTS
const CATEGORIES = [
  "Electronics (Laptop, Phone, Charger)",
  "Keys & Cards (Keys, ID, Credit Card)",
  "Personal Items (Wallet, Bag, Watch)",
  "Documents (Books, Notebooks, Papers)",
  "Clothing (Jacket, Shoes, Scarf)",
  "Other"
];

const LOCATIONS = [
  "Library - 1st Floor",
  "Library - 2nd Floor",
  "Library - 3rd Floor",
  "Cafeteria - Main",
  "Cafeteria - Mini",
  "Parking Lot A",
  "Parking Lot B",
  "Classroom Building",
  "Lab Building",
  "Sports Complex",
  "Other"
];

// 📍 GET CATEGORIES & LOCATIONS
app.get("/get-lost-found-options", (req, res) => {
  res.status(200).json({
    categories: CATEGORIES,
    locations: LOCATIONS
  });
});

// 📍 REPORT LOST/FOUND ITEM
app.post("/report-lost-found-item", (req, res) => {
  const {
    item_name,
    description,
    image1,
    image2,
    type,
    category,
    location,
    reported_by_id,
    reported_by_name,
    reported_by_email,
    reported_by_phone,
    reported_by_role
  } = req.body;

  if (!item_name || !description || !type || !category || !location || !reported_by_id || !reported_by_name || !reported_by_email || !reported_by_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  if (type !== 'lost' && type !== 'found') {
    return res.status(400).json({ message: "Type must be 'lost' or 'found'" });
  }

  if (reported_by_role !== 'Student' && reported_by_role !== 'Teacher') {
    return res.status(400).json({ message: "Only Students and Teachers can report items" });
  }

  const sql = `
    INSERT INTO lost_found_items
    (item_name, description, image1, image2, type, category, location,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone, reported_by_role)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  db.query(
    sql,
    [item_name, description, image1 || null, image2 || null, type, category, location,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone || null, reported_by_role],
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to report item", error: err });
      }

      console.log(`✅ ${type.toUpperCase()} item reported by ${reported_by_name} (ID: ${result.insertId})`);

      // Send confirmation email
      const mailOptions = {
        to: reported_by_email,
        subject: `${type === 'lost' ? 'Lost' : 'Found'} Item Reported - Campus Entry Guide`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">✅ Item Reported Successfully!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${reported_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Your ${type} item has been successfully reported in our Lost & Found system.
              </p>
              
              <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Report Details:</h4>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Type:</strong> ${type === 'lost' ? 'Lost Item' : 'Found Item'}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Category:</strong> ${category}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Location:</strong> ${location}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Reported:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                  <strong>📢 What happens next:</strong><br>
                  • Your item will appear in the Lost & Found list<br>
                  • Others can search and claim it if it belongs to them<br>
                  • You'll be notified when someone claims it<br>
                  • Items are kept for 30 days, then archived
                </p>
              </div>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      mailTransporter.sendMail(mailOptions, (mailErr, info) => {
        if (mailErr) {
          console.error("⚠️ Failed to send confirmation email:", mailErr);
        } else {
          console.log("✅ Confirmation email sent to:", reported_by_email);
        }
      });

      res.status(201).json({
        message: "Item reported successfully",
        itemId: result.insertId,
      });
    }
  );
});

// 📍 GET LOST/FOUND ITEMS (WITH SEARCH & FILTERS)
app.post("/get-lost-found-items", (req, res) => {
  const { userId, userRole, searchQuery, type, status, category, location } = req.body;

  let sql = `SELECT * FROM lost_found_items WHERE is_active = 1`;
  let params = [];

  // Search query (item_name OR description)
  if (searchQuery && searchQuery.trim() !== '') {
    sql += ` AND (item_name LIKE ? OR description LIKE ?)`;
    params.push(`%${searchQuery}%`, `%${searchQuery}%`);
  }

  // Filter by type (lost/found)
  if (type && type !== 'all') {
    sql += ` AND type = ?`;
    params.push(type);
  }

  // Filter by status
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  // Filter by category
  if (category && category !== 'all') {
    sql += ` AND category = ?`;
    params.push(category);
  }

  // Filter by location
  if (location && location !== 'all') {
    sql += ` AND location = ?`;
    params.push(location);
  }

  sql += ` ORDER BY reported_at DESC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch items", error: err });
    }

    console.log(`✅ Fetched ${results.length} lost/found items`);

    // Add flags for current user's permissions
    const enhancedResults = results.map(item => {
      const isOwnReport = item.reported_by_id === userId && item.reported_by_role === userRole;
      const hasClaimed = item.claimed_by_id === userId && item.claimed_by_role === userRole;
      const canEdit = isOwnReport && item.status === 'pending';
      const canClaim = !isOwnReport && item.status === 'pending';
      const canVerify = hasClaimed && item.status === 'pending';

      return {
        ...item,
        isOwnReport,
        hasClaimed,
        canEdit,
        canClaim,
        canVerify
      };
    });

    res.status(200).json({
      message: "Items fetched successfully",
      items: enhancedResults,
    });
  });
});

// 📍 CLAIM ITEM
app.post("/claim-item", (req, res) => {
  const {
    itemId,
    claimed_by_id,
    claimed_by_name,
    claimed_by_email,
    claimed_by_phone,
    claimed_by_role
  } = req.body;

  if (!itemId || !claimed_by_id || !claimed_by_name || !claimed_by_email || !claimed_by_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // First, get the item details
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Check if already claimed
    if (item.status === 'returned') {
      return res.status(400).json({ message: "This item has already been returned" });
    }

    // Check if user is claiming their own report
    if (item.reported_by_id === claimed_by_id && item.reported_by_role === claimed_by_role) {
      return res.status(400).json({ message: "You cannot claim your own report" });
    }

    // Update with claimer info
    const updateSql = `
      UPDATE lost_found_items
      SET claimed_by_id = ?, claimed_by_name = ?, claimed_by_email = ?, 
          claimed_by_phone = ?, claimed_by_role = ?, claimed_at = NOW()
      WHERE id = ?
    `;

    db.query(
      updateSql,
      [claimed_by_id, claimed_by_name, claimed_by_email, claimed_by_phone || null, claimed_by_role, itemId],
      (updateErr, updateResult) => {
        if (updateErr) {
          console.error("❌ Failed to claim item:", updateErr);
          return res.status(500).json({ message: "Failed to claim item", error: updateErr });
        }

        console.log(`✅ Item ${itemId} claimed by ${claimed_by_name}`);

        // Send email to reporter with claimer's contact
        const mailOptions = {
          to: item.reported_by_email,
          subject: `Someone Claimed Your ${item.type === 'lost' ? 'Lost' : 'Found'} Item - Campus Entry Guide`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">🔔 Item Claimed!</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${item.reported_by_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  Good news! Someone has claimed the ${item.type} item you reported.
                </p>
                
                <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Item Details:</h4>
                  <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item.item_name}</p>
                  <p style="color: #1b5e20; margin: 5px 0;"><strong>Category:</strong> ${item.category}</p>
                  <p style="color: #1b5e20; margin: 5px 0;"><strong>Location:</strong> ${item.location}</p>
                </div>
                
                <div style="background-color: #fff3e0; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #e65100; margin: 0 0 10px 0;">Claimer Contact Information:</h4>
                  <p style="color: #bf360c; margin: 5px 0;"><strong>Name:</strong> ${claimed_by_name}</p>
                  <p style="color: #bf360c; margin: 5px 0;"><strong>Email:</strong> ${claimed_by_email}</p>
                  <p style="color: #bf360c; margin: 5px 0;"><strong>Role:</strong> ${claimed_by_role}</p>
                </div>
                
                <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                  <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                    <strong>📢 Next Steps:</strong><br>
                    • Please contact the claimer via email<br>
                    • Arrange a safe meeting location on campus<br>
                    • Verify the item belongs to them<br>
                    • Once confirmed, they will verify in the app
                  </p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr, info) => {
          if (mailErr) {
            console.error("⚠️ Failed to send claim notification email:", mailErr);
          } else {
            console.log("✅ Claim notification sent to:", item.reported_by_email);
          }
        });

        res.status(200).json({
          message: "Item claimed successfully",
          reporterEmail: item.reported_by_email,
          reporterName: item.reported_by_name
        });
      }
    );
  });
});

// 📍 VERIFY ITEM (Mark as Returned)
app.post("/verify-item", (req, res) => {
  const { itemId, userId, userRole } = req.body;

  if (!itemId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get item details first
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Verify the user is the claimer
    if (item.claimed_by_id !== userId || item.claimed_by_role !== userRole) {
      return res.status(403).json({ message: "Only the claimer can verify this item" });
    }

    // Update status to returned
    const updateSql = `
      UPDATE lost_found_items
      SET status = 'returned', verified_at = NOW()
      WHERE id = ?
    `;

    db.query(updateSql, [itemId], (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to verify item:", updateErr);
        return res.status(500).json({ message: "Failed to verify item", error: updateErr });
      }

      console.log(`✅ Item ${itemId} verified as returned by ${item.claimed_by_name}`);

      // Send confirmation emails to both parties
      const reporterMailOptions = {
        to: item.reported_by_email,
        subject: `Item Returned Successfully - Campus Entry Guide`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">🎉 Item Successfully Returned!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${item.reported_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Great news! The ${item.type} item has been successfully returned to its owner.
              </p>
              
              <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Item Details:</h4>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item.item_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Returned to:</strong> ${item.claimed_by_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Verified on:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Thank you for using the Lost & Found system and helping reunite items with their owners!
              </p>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      const claimerMailOptions = {
        to: item.claimed_by_email,
        subject: `Item Verification Confirmed - Campus Entry Guide`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">✅ Verification Confirmed!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${item.claimed_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                You have successfully verified that you received your item. The report has been marked as returned.
              </p>
              
              <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Item Details:</h4>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item.item_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Category:</strong> ${item.category}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Verified on:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                We're glad you got your item back safely!
              </p>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      // Send both emails
      mailTransporter.sendMail(reporterMailOptions, (err1) => {
        if (err1) console.error("⚠️ Failed to send reporter email:", err1);
        else console.log("✅ Verification email sent to reporter");
      });

      mailTransporter.sendMail(claimerMailOptions, (err2) => {
        if (err2) console.error("⚠️ Failed to send claimer email:", err2);
        else console.log("✅ Verification email sent to claimer");
      });

      res.status(200).json({
        message: "Item verified as returned successfully",
      });
    });
  });
});

// 📍 UPDATE LOST/FOUND ITEM (Only before claiming)
app.post("/update-lost-found-item", (req, res) => {
  const {
    itemId,
    userId,
    userRole,
    item_name,
    description,
    image1,
    image2,
    category,
    location
  } = req.body;

  if (!itemId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Check ownership and status
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Check if user owns this report
    if (item.reported_by_id !== userId || item.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only edit your own reports" });
    }

    // Check if item has been claimed
    if (item.status === 'returned' || item.claimed_by_id !== null) {
      return res.status(400).json({ message: "Cannot edit item after it has been claimed" });
    }

    // Build update query
    let updateFields = [];
    let updateValues = [];

    if (item_name) {
      updateFields.push("item_name = ?");
      updateValues.push(item_name);
    }
    if (description) {
      updateFields.push("description = ?");
      updateValues.push(description);
    }
    if (image1 !== undefined) {
      updateFields.push("image1 = ?");
      updateValues.push(image1);
    }
    if (image2 !== undefined) {
      updateFields.push("image2 = ?");
      updateValues.push(image2);
    }
    if (category) {
      updateFields.push("category = ?");
      updateValues.push(category);
    }
    if (location) {
      updateFields.push("location = ?");
      updateValues.push(location);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    updateValues.push(itemId);
    const updateSql = `UPDATE lost_found_items SET ${updateFields.join(", ")} WHERE id = ?`;

    db.query(updateSql, updateValues, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update item:", updateErr);
        return res.status(500).json({ message: "Failed to update item", error: updateErr });
      }

      console.log(`✅ Item ${itemId} updated by ${userRole} ${userId}`);

      res.status(200).json({
        message: "Item updated successfully",
      });
    });
  });
});

// 📍 DELETE LOST/FOUND ITEM (Only before claiming OR by admin)
app.post("/delete-lost-found-item", (req, res) => {
  const { itemId, userId, userRole } = req.body;

  if (!itemId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get item details
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Admin can always delete
    if (userRole === 'Admin') {
      db.query(`DELETE FROM lost_found_items WHERE id = ?`, [itemId], (delErr) => {
        if (delErr) {
          console.error("❌ Failed to delete item:", delErr);
          return res.status(500).json({ message: "Failed to delete item", error: delErr });
        }

        console.log(`✅ Admin deleted item ${itemId}`);
        res.status(200).json({ message: "Item deleted successfully by admin" });
      });
      return;
    }

    // Student/Teacher can only delete their own unclaimed items
    if (item.reported_by_id !== userId || item.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only delete your own reports" });
    }

    if (item.status === 'returned' || item.claimed_by_id !== null) {
      return res.status(400).json({ message: "Cannot delete item after it has been claimed" });
    }

    db.query(`DELETE FROM lost_found_items WHERE id = ?`, [itemId], (delErr) => {
      if (delErr) {
        console.error("❌ Failed to delete item:", delErr);
        return res.status(500).json({ message: "Failed to delete item", error: delErr });
      }

      console.log(`✅ Item ${itemId} deleted by ${userRole} ${userId}`);
      res.status(200).json({ message: "Item deleted successfully" });
    });
  });
});

// 📍 GET ALL LOST/FOUND REPORTS FOR ADMIN
app.get("/get-admin-lost-found-reports", (req, res) => {
  const sql = `
    SELECT * FROM lost_found_items 
    WHERE is_active = 1
    ORDER BY 
      CASE 
        WHEN status = 'pending' THEN 1
        WHEN status = 'returned' THEN 2
      END,
      reported_at DESC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch admin reports", error: err });
    }

    console.log(`✅ Admin fetched ${results.length} lost/found reports`);

    res.status(200).json({
      message: "Reports fetched successfully",
      reports: results,
    });
  });
});

// 📍 AUTO-ARCHIVE CRON JOB (Archive items after 30 days, delete after 50 days)
setInterval(() => {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const fiftyDaysAgo = new Date(Date.now() - 50 * 24 * 60 * 60 * 1000);

  // Archive items older than 30 days
  db.query(
    `UPDATE lost_found_items SET is_active = 0 WHERE reported_at < ? AND is_active = 1`,
    [thirtyDaysAgo],
    (err, result) => {
      if (err) {
        console.error("❌ Auto-archive error:", err);
      } else if (result.affectedRows > 0) {
        console.log(`📦 Auto-archived ${result.affectedRows} items older than 30 days`);
      }
    }
  );

  // Delete items older than 50 days
  db.query(
    `DELETE FROM lost_found_items WHERE reported_at < ?`,
    [fiftyDaysAgo],
    (err, result) => {
      if (err) {
        console.error("❌ Auto-delete error:", err);
      } else if (result.affectedRows > 0) {
        console.log(`🗑️ Auto-deleted ${result.affectedRows} items older than 50 days`);
      }
    }
  );
}, 24 * 60 * 60 * 1000); // Run every 24 hours

console.log("✅ Lost & Found auto-archive system initialized (30 days archive, 50 days delete)")



// ================= COMPLAINT SYSTEM ENDPOINTS =================

// 📍 COMPLAINT CATEGORIES
const COMPLAINT_CATEGORIES = [
  "Room/Facility Issues (AC, Lights, Furniture)",
  "Cleanliness Issues",
  "Safety Concerns",
  "Equipment/Lab Issues",
  "Other"
];

// 📍 GET COMPLAINT OPTIONS
app.get("/get-complaint-options", (req, res) => {
  res.status(200).json({
    categories: COMPLAINT_CATEGORIES,
    locations: LOCATIONS, // Using same locations as Lost & Found
    priorities: ['Low', 'Medium', 'High']
  });
});

// 📍 CREATE COMPLAINT
// 📍 CREATE COMPLAINT
app.post("/create-complaint", (req, res) => {
  const {
    title,
    description,
    category,
    location,
    priority,
    image,
    reported_by_id,
    reported_by_name,
    reported_by_email,
    reported_by_phone,
    reported_by_role,
    reported_by_degree,
    reported_by_section,
    reported_by_department  // ✅ ADD THIS
  } = req.body;

  if (!title || !description || !category || !location || !reported_by_id || !reported_by_name || !reported_by_email || !reported_by_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  if (reported_by_role !== 'Student' && reported_by_role !== 'Teacher') {
    return res.status(400).json({ message: "Only Students and Teachers can file complaints" });
  }

  const sql = `
    INSERT INTO complaints
    (title, description, category, location, priority, image,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone, reported_by_role,
     reported_by_degree, reported_by_section, reported_by_department)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  db.query(
    sql,
    [title, description, category, location, priority || 'Medium', image || null,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone || null, reported_by_role,
     reported_by_degree || null, reported_by_section || null, reported_by_department || null],  // ✅ ADD THIS
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to create complaint", error: err });
      }

      console.log(`✅ Complaint created by ${reported_by_name} (ID: ${result.insertId})`);

      // Send confirmation email to reporter
      const mailOptions = {
        to: reported_by_email,
        subject: "Complaint Submitted Successfully - Campus Entry Guide",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #FF512F; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #FF512F 0%, #DD2476 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">✅ Complaint Submitted!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${reported_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Your complaint has been successfully submitted. Our admin team will review it shortly.
              </p>
              
              <div style="background-color: #fff3e0; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #e65100; margin: 0 0 10px 0;">Complaint Details:</h4>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Title:</strong> ${title}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Category:</strong> ${category}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Location:</strong> ${location}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Priority:</strong> ${priority || 'Medium'}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Status:</strong> Pending</p>
              </div>
              
              <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                  <strong>📢 What happens next:</strong><br>
                  • Admin will review your complaint<br>
                  • You'll be notified when work begins<br>
                  • You'll be notified when issue is resolved<br>
                  • You can track status in the app
                </p>
              </div>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      mailTransporter.sendMail(mailOptions, (mailErr, info) => {
        if (mailErr) {
          console.error("⚠️ Failed to send confirmation email:", mailErr);
        } else {
          console.log("✅ Confirmation email sent to:", reported_by_email);
        }
      });

      // Notify admin about new complaint
      db.query(`SELECT email, full_name FROM admin_registration WHERE id = 1 LIMIT 1`, (adminErr, adminResults) => {
        if (!adminErr && adminResults.length > 0) {
          const admin = adminResults[0];
          const adminMailOptions = {
            to: admin.email,
            subject: "New Complaint Filed - Campus Entry Guide",
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
                <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                  <h2 style="color: #FF512F;">🔔 New Complaint Filed</h2>
                  <p><strong>Title:</strong> ${title}</p>
                  <p><strong>Category:</strong> ${category}</p>
                  <p><strong>Location:</strong> ${location}</p>
                  <p><strong>Priority:</strong> ${priority || 'Medium'}</p>
                  <p><strong>Reported by:</strong> ${reported_by_name} (${reported_by_role})</p>
                  <p>Please check the admin panel for details.</p>
                </div>
              </div>
            `,
          };
          mailTransporter.sendMail(adminMailOptions);
        }
      });

      res.status(201).json({
        message: "Complaint created successfully",
        complaintId: result.insertId,
      });
    }
  );
});

// 📍 GET USER COMPLAINTS (For Students/Teachers)
// 📍 GET USER COMPLAINTS (For Students/Teachers)
app.post("/get-user-complaints", (req, res) => {
  const { userId, userRole, searchQuery, status, category, priority } = req.body;

   let sql = `
    SELECT 
      *,
      reported_by_degree,
      reported_by_section
    FROM complaints 
    WHERE is_active = 1
  `;
  let params = [];

  // Search query
  if (searchQuery && searchQuery.trim() !== '') {
    sql += ` AND (title LIKE ? OR description LIKE ?)`;
    params.push(`%${searchQuery}%`, `%${searchQuery}%`);
  }

  // Filter by status
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  // Filter by category
  if (category && category !== 'all') {
    sql += ` AND category = ?`;
    params.push(category);
  }

  // Filter by priority
  if (priority && priority !== 'all') {
    sql += ` AND priority = ?`;
    params.push(priority);
  }

  sql += ` ORDER BY created_at DESC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch complaints", error: err });
    }

    // ✅ FIX: Always show full info, add flags for permissions
    const sanitizedResults = results.map(complaint => {
      const isOwnComplaint = complaint.reported_by_id === userId && complaint.reported_by_role === userRole;
      
      return {
        ...complaint,
        isOwnComplaint: isOwnComplaint,
        canEdit: isOwnComplaint && complaint.status === 'pending',
        canDelete: isOwnComplaint && !complaint.verified_by_reporter
      };
    });

    res.status(200).json({
      message: "Complaints fetched successfully",
      complaints: sanitizedResults,
    });
  });
});

// ================= REPLACE THE EXISTING /get-admin-complaints ENDPOINT WITH THIS =================

app.post("/get-admin-complaints", (req, res) => {
  const { reporterRole, status, category, priority, location, searchQuery } = req.body;

  let sql = `
    SELECT 
      *,
      reported_by_degree,
      reported_by_section
    FROM complaints 
    WHERE is_active = 1
  `;
  let params = [];

  // Filter by reporter role (Student, Teacher, or null for all)
  if (reporterRole && reporterRole !== 'all') {
    sql += ` AND reported_by_role = ?`;
    params.push(reporterRole);
  }

  // Filter by status
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  // Filter by category
  if (category && category !== 'all') {
    sql += ` AND category = ?`;
    params.push(category);
  }

  // Filter by priority
  if (priority && priority !== 'all') {
    sql += ` AND priority = ?`;
    params.push(priority);
  }

  // Filter by location
  if (location && location !== 'all') {
    sql += ` AND location = ?`;
    params.push(location);
  }

  // Search query across title, description, name, email
  if (searchQuery && searchQuery.trim() !== '') {
    sql += ` AND (title LIKE ? OR description LIKE ? OR reported_by_name LIKE ? OR reported_by_email LIKE ?)`;
    params.push(`%${searchQuery}%`, `%${searchQuery}%`, `%${searchQuery}%`, `%${searchQuery}%`);
  }

  sql += ` ORDER BY 
    CASE 
      WHEN status = 'pending' THEN 1
      WHEN status = 'in_progress' THEN 2
      WHEN status = 'resolved' THEN 3
    END,
    created_at DESC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch complaints", error: err });
    }

    console.log(`✅ Admin fetched ${results.length} complaints`);

    res.status(200).json({
      message: "Complaints fetched successfully",
      complaints: results,
    });
  });
});

// 📍 UPDATE COMPLAINT STATUS (Admin)
app.post("/update-complaint-status", (req, res) => {
  const { complaintId, status, adminId, adminName, adminResponse } = req.body;

  if (!complaintId || !status || !adminId) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details first
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    let updateSql = `UPDATE complaints SET status = ?, admin_id = ?, admin_name = ?`;
    let updateParams = [status, adminId, adminName];

    if (adminResponse) {
      updateSql += `, admin_response = ?`;
      updateParams.push(adminResponse);
    }

    if (status === 'in_progress' && !complaint.admin_started_at) {
      updateSql += `, admin_started_at = NOW()`;
    }

    if (status === 'resolved' && !complaint.resolved_at) {
      updateSql += `, resolved_at = NOW()`;
    }

    updateSql += ` WHERE id = ?`;
    updateParams.push(complaintId);

    db.query(updateSql, updateParams, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update status:", updateErr);
        return res.status(500).json({ message: "Failed to update status", error: updateErr });
      }

      console.log(`✅ Complaint ${complaintId} status updated to ${status} by admin ${adminName}`);

      // Send email notification to reporter
      let emailSubject = "";
      let emailMessage = "";
      let emailColor = "";

      if (status === 'in_progress') {
        emailSubject = "Work Started on Your Complaint - Campus Entry Guide";
        emailMessage = "Good news! The admin team has started working on your complaint.";
        emailColor = "#2196F3";
      } else if (status === 'resolved') {
        emailSubject = "Complaint Resolved - Campus Entry Guide";
        emailMessage = "Great news! Your complaint has been marked as resolved by the admin team.";
        emailColor = "#4CAF50";
      }

      if (emailSubject) {
        const mailOptions = {
          to: complaint.reported_by_email,
          subject: emailSubject,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: ${emailColor}; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: ${emailColor}; padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">${status === 'in_progress' ? '🔧' : '✅'} Status Update</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${complaint.reported_by_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  ${emailMessage}
                </p>
                
                <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #333; margin: 0 0 10px 0;">Complaint Details:</h4>
                  <p style="margin: 5px 0;"><strong>Title:</strong> ${complaint.title}</p>
                  <p style="margin: 5px 0;"><strong>Category:</strong> ${complaint.category}</p>
                  <p style="margin: 5px 0;"><strong>Status:</strong> ${status === 'in_progress' ? 'In Progress' : 'Resolved'}</p>
                </div>
                
                ${adminResponse ? `
                <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Admin Response:</h4>
                  <p style="color: #1b5e20; margin: 0;">${adminResponse}</p>
                </div>
                ` : ''}
                
                ${status === 'resolved' ? `
                <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
                  <p style="color: #856404; margin: 0; font-size: 14px;">
                    <strong>⚠️ Next Step:</strong><br>
                    Please verify in the app if the issue is actually resolved. If verified, you can allow admin to delete this complaint.
                  </p>
                </div>
                ` : ''}
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr, info) => {
          if (mailErr) {
            console.error("⚠️ Failed to send status update email:", mailErr);
          } else {
            console.log("✅ Status update email sent to:", complaint.reported_by_email);
          }
        });
      }

      res.status(200).json({
        message: "Complaint status updated successfully",
      });
    });
  });
});

// 📍 VERIFY COMPLAINT BY REPORTER
app.post("/verify-complaint", (req, res) => {
  const { complaintId, userId, userRole, allowAdminDelete } = req.body;

  if (!complaintId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    // Verify ownership
    if (complaint.reported_by_id !== userId || complaint.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only verify your own complaints" });
    }

    // Check if already verified
    if (complaint.verified_by_reporter) {
      return res.status(400).json({ message: "Complaint already verified" });
    }

    // Update verification
    const updateSql = `
      UPDATE complaints 
      SET verified_by_reporter = 1, verified_at = NOW(), allow_admin_delete = ?
      WHERE id = ?
    `;

    db.query(updateSql, [allowAdminDelete ? 1 : 0, complaintId], (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to verify complaint:", updateErr);
        return res.status(500).json({ message: "Failed to verify complaint", error: updateErr });
      }

      console.log(`✅ Complaint ${complaintId} verified by reporter ${userId}`);

      // If admin deletion is allowed, notify admin
      if (allowAdminDelete) {
        db.query(`SELECT email FROM admin_registration WHERE id = 1 LIMIT 1`, (adminErr, adminResults) => {
          if (!adminErr && adminResults.length > 0) {
            const adminMailOptions = {
              to: adminResults[0].email,
              subject: "Complaint Ready for Deletion - Campus Entry Guide",
              html: `
                <div style="font-family: Arial, sans-serif;">
                  <h2>Complaint Verified & Ready for Deletion</h2>
                  <p><strong>Title:</strong> ${complaint.title}</p>
                  <p><strong>Reporter:</strong> ${complaint.reported_by_name}</p>
                  <p>The reporter has verified the resolution and allowed deletion.</p>
                </div>
              `,
            };
            mailTransporter.sendMail(adminMailOptions);
          }
        });
      }

      res.status(200).json({
        message: "Complaint verified successfully",
      });
    });
  });
});

// 📍 UPDATE COMPLAINT (By Reporter - Only Pending Status)
app.post("/update-complaint", (req, res) => {
  const {
    complaintId,
    userId,
    userRole,
    title,
    description,
    category,
    location,
    priority,
    image
  } = req.body;

  if (!complaintId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    // Verify ownership
    if (complaint.reported_by_id !== userId || complaint.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only edit your own complaints" });
    }

    // Check if editable
    if (complaint.status !== 'pending') {
      return res.status(400).json({ message: "Can only edit complaints with pending status" });
    }

    // Build update query
    let updateFields = [];
    let updateValues = [];

    if (title) {
      updateFields.push("title = ?");
      updateValues.push(title);
    }
    if (description) {
      updateFields.push("description = ?");
      updateValues.push(description);
    }
    if (category) {
      updateFields.push("category = ?");
      updateValues.push(category);
    }
    if (location) {
      updateFields.push("location = ?");
      updateValues.push(location);
    }
    if (priority) {
      updateFields.push("priority = ?");
      updateValues.push(priority);
    }
    if (image !== undefined) {
      updateFields.push("image = ?");
      updateValues.push(image);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    updateValues.push(complaintId);
    const updateSql = `UPDATE complaints SET ${updateFields.join(", ")} WHERE id = ?`;

    db.query(updateSql, updateValues, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update complaint:", updateErr);
        return res.status(500).json({ message: "Failed to update complaint", error: updateErr });
      }

      console.log(`✅ Complaint ${complaintId} updated`);

      res.status(200).json({
        message: "Complaint updated successfully",
      });
    });
  });
});

// 📍 DELETE COMPLAINT
app.post("/delete-complaint", (req, res) => {
  const { complaintId, userId, userRole } = req.body;

  if (!complaintId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    // Admin can delete if reporter allowed
    if (userRole === 'Admin') {
      if (!complaint.allow_admin_delete) {
        return res.status(403).json({ message: "Reporter has not allowed deletion yet" });
      }

      db.query(`DELETE FROM complaints WHERE id = ?`, [complaintId], (delErr) => {
        if (delErr) {
          console.error("❌ Failed to delete complaint:", delErr);
          return res.status(500).json({ message: "Failed to delete complaint", error: delErr });
        }

        console.log(`✅ Admin deleted complaint ${complaintId}`);
        res.status(200).json({ message: "Complaint deleted successfully by admin" });
      });
      return;
    }

    // Reporter can delete before verification
    if (complaint.reported_by_id !== userId || complaint.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only delete your own complaints" });
    }

    if (complaint.verified_by_reporter) {
      return res.status(400).json({ message: "Cannot delete after verification" });
    }

    db.query(`DELETE FROM complaints WHERE id = ?`, [complaintId], (delErr) => {
      if (delErr) {
        console.error("❌ Failed to delete complaint:", delErr);
        return res.status(500).json({ message: "Failed to delete complaint", error: delErr });
      }

      console.log(`✅ Reporter deleted complaint ${complaintId}`);
      res.status(200).json({ message: "Complaint deleted successfully" });
    });
  });
});

// 📍 ADD COMMENT TO COMPLAINT
app.post("/add-complaint-comment", (req, res) => {
  const { complaintId, userId, userName, userRole, comment } = req.body;

  console.log("📝 Adding comment:", {
    complaintId,
    userId,
    userName,
    userRole,
    comment: comment.substring(0, 50) + '...'
  });

  if (!complaintId || !userId || !userName || !userRole || !comment) {
    console.log("❌ Missing fields:", { complaintId, userId, userName, userRole, hasComment: !!comment });
    return res.status(400).json({ message: "Required fields missing" });
  }

  const sql = `
    INSERT INTO complaint_comments (complaint_id, user_id, user_name, user_role, comment, created_at)
    VALUES (?, ?, ?, ?, ?, NOW())
  `;

  db.query(sql, [complaintId, userId, userName, userRole, comment], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to add comment", error: err });
    }

    console.log(`✅ Comment added to complaint ${complaintId} by ${userName} (${userRole})`);

    res.status(201).json({
      message: "Comment added successfully",
      commentId: result.insertId,
    });
  });
});

// 📍 GET TOTAL COMPLAINT COUNT (For Badge Display)
app.post("/get-total-complaints-count", (req, res) => {
  const { userRole, status } = req.body;

  let sql = `SELECT COUNT(*) as totalCount FROM complaints WHERE is_active = 1`;
  let params = [];

  // If status filter is provided
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  console.log('📊 Fetching total complaints count');
  console.log('   SQL:', sql);
  console.log('   Params:', params);

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch count", error: err });
    }

    const totalCount = results[0].totalCount || 0;
    console.log(`✅ Total complaints: ${totalCount}`);

    res.status(200).json({
      message: "Count fetched successfully",
      totalCount: totalCount,
    });
  });
});


// 📍 MARK ALL COMPLAINTS AS VIEWED
app.post("/mark-all-complaints-viewed", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  console.log(`👁️ Marking all complaints as viewed for user ${userId} (${userRole})`);

  const sql = `
    INSERT INTO complaint_views (user_id, user_role, last_viewed_at)
    VALUES (?, ?, NOW())
    ON DUPLICATE KEY UPDATE last_viewed_at = NOW()
  `;

  db.query(sql, [userId, userRole], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to mark as viewed", error: err });
    }

    console.log(`✅ All complaints marked as viewed for user ${userId}`);

    res.status(200).json({
      message: "All complaints marked as viewed",
    });
  });
});

// 📍 GET UNVIEWED COMPLAINTS COUNT (For Badge)
app.post("/get-unviewed-complaints-count", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const sql = `
    SELECT COUNT(*) as unviewedCount
    FROM complaints c
    LEFT JOIN complaint_views cv ON cv.user_id = ? AND cv.user_role = ?
    WHERE c.is_active = 1
      AND (cv.last_viewed_at IS NULL OR c.created_at > cv.last_viewed_at)
  `;

  db.query(sql, [userId, userRole], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch count", error: err });
    }

    const unviewedCount = results[0].unviewedCount || 0;
    console.log(`✅ Unviewed complaints for user ${userId}: ${unviewedCount}`);

    res.status(200).json({
      message: "Unviewed count fetched successfully",
      unviewedCount: unviewedCount,
    });
  });
});


// 📍 GET COMPLAINT COMMENTS
app.post("/get-complaint-comments", (req, res) => {
  const { complaintId } = req.body;

  if (!complaintId) {
    return res.status(400).json({ message: "Complaint ID is required" });
  }

  const sql = `
    SELECT 
      id,
      complaint_id,
      user_id,
      user_name,
      user_role,
      comment,
      created_at
    FROM complaint_comments 
    WHERE complaint_id = ?
    ORDER BY created_at ASC
  `;

  db.query(sql, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch comments", error: err });
    }

    console.log(`✅ Fetched ${results.length} comments for complaint ${complaintId}`);
    
    // Log each comment to debug
    results.forEach(comment => {
      console.log(`   Comment by ${comment.user_name} (${comment.user_role}): ${comment.comment.substring(0, 30)}...`);
    });

    res.status(200).json({
      message: "Comments fetched successfully",
      comments: results,
    });
  });
});

console.log("✅ Complaint System endpoints initialized");

// ================= START SERVER =================
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});