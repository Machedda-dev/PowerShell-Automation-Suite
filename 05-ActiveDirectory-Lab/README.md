# Active Directory Lab (Windows Server 2022)

## Project Overview
Built a fully functional Windows Server 2022 Domain Controller from scratch using Hyper-V. This project demonstrates enterprise-level identity management, Group Policy enforcement, and secure network configuration.

## Technologies Used
- **Virtualization:** Hyper-V (Generation 2 VM)
- **Operating System:** Windows Server 2022 Standard (Desktop Experience)
- **Active Directory:** AD DS, Organizational Units (OUs), Security Groups
- **Group Policy:** GPOs for desktop configuration enforcement
- **Networking:** External virtual switch for internet connectivity

## Key Achievements
- Designed and deployed a domain controller (`lab.local`) from ISO installation.
- Created Organizational Units to logically structure users (`Corp_Users`).
- Provisioned domain user accounts and security groups (`IT_Admins`).
- Implemented Group Policy Objects to enforce desktop settings across the domain.
- Configured DNS services and verified network resolution.

## How to Reproduce
1. Install Hyper-V on Windows 10/11 Pro.
2. Download Windows Server 2022 ISO.
3. Create a Generation 2 VM with 2048 MB RAM and 60 GB dynamic disk.
4. Install Server with Desktop Experience.
5. Run PowerShell commands to install AD DS and promote to Domain Controller.

## Screenshots<img width="954" height="692" alt="ScreenShot Active_Dir" src="https://github.com/user-attachments/assets/53549992-37ce-4f2f-80b1-ce02eb4fa52d" />

## Author
Vincent Ododa
