# Git Operations Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press f for fetch| C[Git Fetch]
    B -->|Press P for push| D[Git Push]
    B -->|leader+a action menu| E[Action Menu]
    B -->|Command Flow Interface| F[Command Flow]
    
    %% Git Fetch Flow
    C --> G[git_fetch]
    G --> H{Async Mode?}
    H -->|Yes| I[git_fetch_async]
    H -->|No| J[Synchronous fetch]
    
    %% Git Push Flow
    D --> K[git_push]
    K --> L{Async Mode?}
    L -->|Yes| M[git_push_async]
    L -->|No| N[Synchronous push]
    
    %% Action Menu Flow
    E --> O{Menu Selection}
    O -->|Git Fetch| P[Git fetch f]
    O -->|Git Push| Q[Git push P]
    P --> G
    Q --> K
    
    %% Command Flow Interface
    F --> R[Step 1: Operation Selection]
    R --> S[Step 2: Options Menu]
    S --> T[Step 3: Execute]
    T --> U{Operation Type}
    U -->|Fetch| G
    U -->|Push| K
    
    %% Async Fetch Execution
    I --> V[Show progress indicator]
    V --> W[Build jj git fetch command]
    W --> X[jj git fetch]
    X --> Y[Monitor progress]
    Y --> Z[Handle completion]
    
    %% Sync Fetch Execution
    J --> AA[Build jj git fetch command]
    AA --> BB[jj git fetch]
    BB --> CC[Handle result]
    
    %% Async Push Execution
    M --> DD[Show progress indicator]
    DD --> EE[Build jj git push command]
    EE --> FF[jj git push]
    FF --> GG[Monitor progress]
    GG --> HH[Handle completion]
    
    %% Sync Push Execution
    N --> II[Build jj git push command]
    II --> JJ[jj git push]
    JJ --> KK[Handle result]
    
    %% Smart Error Handling - Push
    FF --> LL{Push Error?}
    JJ --> LL
    LL -->|Bookmark Error| MM[Parse error message]
    LL -->|Other Error| NN[Show error message]
    LL -->|Success| OO[Show success message]
    
    MM --> PP{New Bookmark?}
    PP -->|Yes| QQ[Show retry dialog]
    PP -->|No| NN
    
    QQ --> RR{User Confirms?}
    RR -->|Yes| SS[Retry with --allow-new]
    RR -->|No| TT[Cancel operation]
    
    SS --> UU[jj git push --allow-new]
    UU --> VV[Handle retry result]
    VV --> WW{Retry Success?}
    WW -->|Yes| OO
    WW -->|No| NN
    
    %% Fetch Completion
    Z --> XX{Fetch Success?}
    CC --> XX
    XX -->|Yes| YY[Show success notification]
    XX -->|No| ZZ[Show error message]
    
    %% Push Completion
    HH --> AAA{Push Success?}
    KK --> AAA
    AAA -->|Yes| OO
    AAA -->|No| LL
    
    %% Success Path
    YY --> BBB[Refresh log display]
    OO --> BBB
    BBB --> CCC[Update remote tracking]
    CCC --> DDD[Show operation summary]
    
    %% Error Handling
    ZZ --> EEE[Return to previous state]
    NN --> EEE
    TT --> EEE
    
    %% Progress Indicators
    V --> FFF[Show fetch progress]
    FFF --> GGG[Animated spinner]
    GGG --> HHH[Status updates]
    
    DD --> III[Show push progress]
    III --> JJJ[Animated spinner]
    JJJ --> KKK[Status updates]
    
    %% Additional Options
    W --> LLL{Fetch Options}
    LLL -->|All Remotes| MMM[--all-remotes flag]
    LLL -->|Specific Remote| NNN[--remote remote_name]
    LLL -->|Default| OOO[No additional flags]
    
    MMM --> X
    NNN --> X
    OOO --> X
    
    EE --> PPP{Push Options}
    PPP -->|All Bookmarks| QQQ[--all flag]
    PPP -->|Specific Bookmark| RRR[--bookmark bookmark_name]
    PPP -->|Current| SSS[No additional flags]
    
    QQQ --> FF
    RRR --> FF
    SSS --> FF
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef progress fill:#f3e5f5
    classDef smart fill:#e1f5fe
    
    class A,B,C,D,E,F userAction
    class O,P,Q,R,S,T,U menuAction
    class G,I,J,K,M,N,W,X,AA,BB,EE,FF,II,JJ,UU,VV execution
    class command command
    class YY,OO,BBB,CCC,DDD success
    class ZZ,NN,EEE error
    class V,DD,FFF,GGG,HHH,III,JJJ,KKK progress
    class MM,PP,QQ,RR,SS,UU,VV,WW smart
```

## Key Features

- **Async Operations**: Non-blocking fetch and push with progress indicators
- **Smart Error Handling**: Automatic retry with `--allow-new` for bookmark errors
- **Progress Feedback**: Visual progress indicators for long operations
- **Flexible Options**: Support for all remotes, specific remotes, specific bookmarks

## Git Operations

### Fetch
- **Command**: `jj git fetch`
- **Options**: `--all-remotes`, `--remote <name>`
- **Async**: Shows progress spinner and status updates

### Push
- **Command**: `jj git push`
- **Options**: `--all`, `--bookmark <name>`, `--allow-new`
- **Smart Retry**: Automatically suggests `--allow-new` for new bookmarks

## Smart Error Handling

The push operation includes intelligent error handling:
1. **Bookmark Errors**: Detects new bookmark errors and offers to retry with `--allow-new`
2. **User Confirmation**: Shows dialog explaining the retry option
3. **Automatic Retry**: Executes retry with appropriate flags
4. **Fallback**: Returns to error state if retry fails

## File Locations

- **Core**: `lua/jj-nvim/jj/git.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:541-545`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:162-171`
- **Command Flow**: `lua/jj-nvim/ui/command_flow.lua:132-167`
- **Keybindings**: `f` for fetch, `P` for push